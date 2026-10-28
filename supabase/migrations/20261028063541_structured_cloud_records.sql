-- Protocol 2: private, paginated records and atomic delta writes. The original
-- workspace remains intact as a migration fallback; upgraded accounts block old
-- writers. Sharing uses a separate permission model in a later migration.
create schema if not exists carty_private;
revoke all on schema carty_private from public, anon;
grant usage on schema carty_private to authenticated;

create table public.carty_cloud_heads (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null check (revision > 0),
  protocol integer not null default 2 check (protocol = 2),
  metadata jsonb not null check (coalesce(
    jsonb_typeof(metadata) = 'object'
    and jsonb_typeof(metadata->'fields') = 'object'
    and metadata->'fields'->>'version' = '3'
    and jsonb_typeof(metadata->'collections') = 'array'
    and metadata->'collections' @> '["items","savedLists","history"]'
    and octet_length(metadata::text) <= 65536, false)),
  record_count bigint not null default 0 check (record_count >= 0),
  updated_at timestamptz not null default now()
);
create table public.carty_cloud_records (
  user_id uuid not null references public.carty_cloud_heads(user_id) on delete cascade,
  kind text not null check (kind in ('items','lists','listItems','trips','tripItems','tripPlanItems','preferences')),
  parent_id text not null check (char_length(parent_id) <= 256),
  record_id text not null check (char_length(record_id) between 1 and 256),
  position integer not null check (position >= 0),
  revision bigint not null check (revision > 0),
  data jsonb not null check (jsonb_typeof(data) = 'object' and octet_length(data::text) <= 65536),
  primary key (user_id, kind, parent_id, record_id),
  unique (user_id, kind, parent_id, position) deferrable initially deferred,
  check ((kind in ('items','lists','trips','preferences') and parent_id = '')
      or (kind in ('listItems','tripItems','tripPlanItems') and parent_id <> '')),
  check (coalesce(case kind
    when 'preferences' then data->>'name' = record_id
    when 'trips' then data->'fields'->>'id' = record_id and jsonb_typeof(data->'hasPlan') = 'boolean'
    else data->>'id' = record_id end, false))
);
alter table public.carty_cloud_heads enable row level security;
alter table public.carty_cloud_records enable row level security;
revoke all on public.carty_cloud_heads, public.carty_cloud_records from public, anon, authenticated;
grant select on public.carty_cloud_heads, public.carty_cloud_records to authenticated;
create policy "Read own cloud head" on public.carty_cloud_heads for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Read own cloud records" on public.carty_cloud_records for select to authenticated
  using ((select auth.uid()) = user_id);

-- All protocol-1 and protocol-2 mutations take the same owner lock. This prevents
-- an old save racing the first migration and being lost between storage formats.
create function carty_private.bootstrap_records()
returns setof public.carty_cloud_heads
language plpgsql security definer set search_path = '' as $$
declare caller uuid := auth.uid(); old public.carty_workspaces;
begin
  if caller is null or not exists(select 1 from auth.users where id = caller) then
    raise exception 'Sign in before syncing' using errcode = '42501';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(caller::text, 0));
  if exists(select 1 from public.carty_cloud_heads where user_id = caller) then
    return query select * from public.carty_cloud_heads where user_id = caller;
    return;
  end if;
  select * into old from public.carty_workspaces where user_id = caller;
  if not found then return; end if;
  insert into public.carty_cloud_heads(user_id, revision, metadata)
  values(caller, old.revision, jsonb_build_object(
    'fields', old.snapshot - 'items' - 'savedLists' - 'history' - 'productPreferences',
    'collections', '["items","savedLists","history"]'::jsonb ||
      case when old.snapshot ? 'productPreferences' then '["productPreferences"]'::jsonb else '[]'::jsonb end));
  insert into public.carty_cloud_records(user_id, kind, parent_id, record_id, position, revision, data)
  select caller, 'items', '', x.value->>'id', (x.ordinality-1)::integer, old.revision, x.value
    from jsonb_array_elements(old.snapshot->'items') with ordinality x
  union all
  select caller, 'lists', '', x.value->>'id', (x.ordinality-1)::integer, old.revision, x.value - 'items'
    from jsonb_array_elements(old.snapshot->'savedLists') with ordinality x
  union all
  select caller, 'listItems', l.value->>'id', x.value->>'id', (x.ordinality-1)::integer, old.revision, x.value
    from jsonb_array_elements(old.snapshot->'savedLists') l,
      lateral jsonb_array_elements(l.value->'items') with ordinality x
  union all
  select caller, 'trips', '', x.value->>'id', (x.ordinality-1)::integer, old.revision,
    jsonb_build_object('fields', x.value - 'items' - 'plannedItems', 'hasPlan', x.value ? 'plannedItems')
    from jsonb_array_elements(old.snapshot->'history') with ordinality x
  union all
  select caller, 'tripItems', t.value->>'id', x.value->>'id', (x.ordinality-1)::integer, old.revision, x.value
    from jsonb_array_elements(old.snapshot->'history') t,
      lateral jsonb_array_elements(t.value->'items') with ordinality x
  union all
  select caller, 'tripPlanItems', t.value->>'id', x.value->>'id', (x.ordinality-1)::integer, old.revision, x.value
    from jsonb_array_elements(old.snapshot->'history') t,
      lateral jsonb_array_elements(coalesce(t.value->'plannedItems', '[]'::jsonb)) with ordinality x
  union all
  select caller, 'preferences', '', x.value->>'name', (x.ordinality-1)::integer, old.revision, x.value
    from jsonb_array_elements(coalesce(old.snapshot->'productPreferences', '[]'::jsonb)) with ordinality x;
  update public.carty_cloud_heads h set record_count =
    (select count(*) from public.carty_cloud_records r where r.user_id = caller)
    where h.user_id = caller;
  return query select * from public.carty_cloud_heads where user_id = caller;
end $$;
revoke all on function carty_private.bootstrap_records() from public, anon, authenticated;
grant execute on function carty_private.bootstrap_records() to authenticated;
create function public.carty_bootstrap_records()
returns setof public.carty_cloud_heads language sql security invoker set search_path = ''
as $$ select * from carty_private.bootstrap_records() $$;
revoke all on function public.carty_bootstrap_records() from public, anon;
grant execute on function public.carty_bootstrap_records() to authenticated;

create function carty_private.save_record_delta(
  p_protocol integer, p_expected_revision bigint, p_metadata jsonb,
  p_upserts jsonb, p_deletes jsonb)
returns setof public.carty_cloud_heads
language plpgsql security definer set search_path = '' as $$
declare caller uuid := auth.uid(); head public.carty_cloud_heads; next_revision bigint;
begin
  if caller is null or not exists(select 1 from auth.users where id = caller) then
    raise exception 'Sign in before saving' using errcode = '42501';
  end if;
  if p_protocol is distinct from 2 or p_expected_revision is null or p_expected_revision < 0
    or jsonb_typeof(p_upserts) is distinct from 'array'
    or jsonb_typeof(p_deletes) is distinct from 'array'
    or jsonb_array_length(p_upserts) + jsonb_array_length(p_deletes) > 20000 then
    raise exception 'Unsupported cloud protocol or patch' using errcode = '22023';
  end if;
  perform * from carty_private.bootstrap_records();
  select * into head from public.carty_cloud_heads where user_id = caller;
  if coalesce(head.revision, 0) <> p_expected_revision then return; end if;
  next_revision := p_expected_revision + 1;
  if head.user_id is null then
    insert into public.carty_cloud_heads(user_id, revision, metadata) values(caller, next_revision, p_metadata);
  else
    update public.carty_cloud_heads set revision = next_revision, metadata = p_metadata, updated_at = now()
      where user_id = caller;
  end if;
  delete from public.carty_cloud_records r using jsonb_to_recordset(p_deletes)
    as x(kind text, parent_id text, record_id text)
    where r.user_id = caller and r.kind = x.kind and r.parent_id = x.parent_id and r.record_id = x.record_id;
  insert into public.carty_cloud_records(user_id, kind, parent_id, record_id, position, revision, data)
    select caller, x.kind, x.parent_id, x.record_id, x.position, next_revision, x.data
    from jsonb_to_recordset(p_upserts) as x(kind text, parent_id text, record_id text, position integer, data jsonb)
    on conflict (user_id, kind, parent_id, record_id) do update
      set position = excluded.position, data = excluded.data, revision = excluded.revision
      where (carty_cloud_records.position, carty_cloud_records.data) is distinct from (excluded.position, excluded.data);
  -- A patch is atomic and must leave a complete, ordered graph. Malformed patches
  -- roll back the head revision too, instead of publishing partial collections.
  if exists(select 1 from public.carty_cloud_records where user_id = caller
    group by kind, parent_id having min(position) <> 0 or max(position) <> count(*) - 1 or count(distinct position) <> count(*))
    or exists(select 1 from public.carty_cloud_records r where r.user_id = caller
      and r.kind in ('listItems','tripItems','tripPlanItems') and not exists(
        select 1 from public.carty_cloud_records p where p.user_id = caller and p.parent_id = ''
          and p.record_id = r.parent_id and p.kind = case when r.kind = 'listItems' then 'lists' else 'trips' end)) then
    raise exception 'Invalid record graph' using errcode = '23514';
  end if;
  update public.carty_cloud_heads h set record_count =
    (select count(*) from public.carty_cloud_records r where r.user_id = caller)
    where h.user_id = caller;
  return query select * from public.carty_cloud_heads where user_id = caller;
end $$;
revoke all on function carty_private.save_record_delta(integer,bigint,jsonb,jsonb,jsonb) from public, anon, authenticated;
grant execute on function carty_private.save_record_delta(integer,bigint,jsonb,jsonb,jsonb) to authenticated;
create function public.carty_save_record_delta(
  p_protocol integer, p_expected_revision bigint, p_metadata jsonb, p_upserts jsonb, p_deletes jsonb)
returns setof public.carty_cloud_heads language sql security invoker set search_path = ''
as $$ select * from carty_private.save_record_delta(p_protocol,p_expected_revision,p_metadata,p_upserts,p_deletes) $$;
revoke all on function public.carty_save_record_delta(integer,bigint,jsonb,jsonb,jsonb) from public, anon;
grant execute on function public.carty_save_record_delta(integer,bigint,jsonb,jsonb,jsonb) to authenticated;

-- Existing clients continue to work until their account adopts protocol 2.
create or replace function public.carty_save_workspace(p_expected_revision bigint, p_snapshot jsonb)
returns setof public.carty_workspaces language plpgsql security definer set search_path = '' as $$
declare owner_id uuid := auth.uid();
begin
  if owner_id is null then raise exception 'Sign in before saving' using errcode = '42501'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(owner_id::text, 0));
  if exists(select 1 from public.carty_cloud_heads where user_id = owner_id) then
    raise exception 'Update Carty before saving this account' using errcode = '22023';
  end if;
  if p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'Invalid workspace revision' using errcode = '22023';
  end if;
  if p_expected_revision = 0 then
    return query insert into public.carty_workspaces(user_id, revision, snapshot) values(owner_id, 1, p_snapshot)
      on conflict (user_id) do nothing returning *;
  else
    return query update public.carty_workspaces set snapshot=p_snapshot, revision=revision+1, updated_at=now()
      where user_id=owner_id and revision=p_expected_revision returning *;
  end if;
end $$;
