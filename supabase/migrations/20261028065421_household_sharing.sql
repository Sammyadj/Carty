-- Household lists are separate from private workspaces. No direct client writes.
-- Invitations are addressed to a verified account email and visible in-app.
-- Email notification delivery is a separate provider configuration step.
create function carty_private.valid_gtin(value text) returns boolean
language plpgsql immutable security invoker set search_path = '' as $$
declare total integer := 0; weight integer := 3; i integer;
begin
  if value is null or char_length(value) not in (8,12,13,14) or value !~ '^[0-9]+$' then return false; end if;
  for i in reverse char_length(value)-1..1 loop
    total := total + substring(value,i,1)::integer * weight;
    weight := 4 - weight;
  end loop;
  return (10 - total % 10) % 10 = right(value,1)::integer;
end $$;
revoke all on function carty_private.valid_gtin(text) from public, anon, authenticated;

create function carty_private.valid_shared_item(item jsonb) returns boolean
language plpgsql immutable security invoker set search_path = '' as $$
declare field text; product jsonb;
begin
  if jsonb_typeof(item) is distinct from 'object' or octet_length(item::text)>65536
    or jsonb_typeof(item->'id') is distinct from 'string' or char_length(item->>'id') not between 1 and 256
    or jsonb_typeof(item->'name') is distinct from 'string' or char_length(btrim(item->>'name')) not between 1 and 120
    or jsonb_typeof(item->'priceConfirmed') is distinct from 'boolean'
    or coalesce(item->>'category','') not in ('automatic','produce','dairyAndEggs','meatAndFish','bakery','pantry','frozen','drinks','household','personalCare','other') then return false; end if;
  foreach field in array array['quantity','plannedQuantity','unitPricePence','estimatedUnitPricePence'] loop
    if jsonb_typeof(item->field) is distinct from 'number' or item->>field !~ '^(0|[1-9][0-9]*)$' then return false; end if;
    if field in ('quantity','plannedQuantity') then
      if (item->>field)::numeric > 9999 then return false; end if;
    elsif (item->>field)::numeric not between 1 and 999999999 then return false;
    end if;
  end loop;
  if item ? 'product' then
    product := item->'product';
    if jsonb_typeof(product) is distinct from 'object'
      or jsonb_typeof(product->'barcode') is distinct from 'string'
      or not carty_private.valid_gtin(product->>'barcode')
      or jsonb_typeof(product->'name') is distinct from 'string'
      or char_length(btrim(product->>'name')) not between 1 and 120 then return false; end if;
    foreach field in array array['brand','packSize'] loop
      if product ? field and jsonb_typeof(product->field) <> 'null' and
        (jsonb_typeof(product->field) <> 'string' or char_length(product->>field)>120) then return false; end if;
    end loop;
    if product ? 'source' and jsonb_typeof(product->'source') <> 'null' and
      coalesce(product->>'source','') not in ('manual','openFoodFacts','upcitemdb') then return false; end if;
    if product ? 'fromOpenFoodFacts' and jsonb_typeof(product->'fromOpenFoodFacts') not in ('boolean','null') then return false; end if;
  end if;
  return true;
exception when others then return false;
end $$;
revoke all on function carty_private.valid_shared_item(jsonb) from public, anon, authenticated;

create table public.carty_shared_lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  budget_pence bigint check (budget_pence between 1 and 999999999),
  is_planning boolean not null default true,
  currency text not null default 'GBP' check (currency='GBP'),
  revision bigint not null default 1 check (revision>0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index carty_shared_lists_owner_idx on public.carty_shared_lists(owner_id);
create table public.carty_shared_items (
  list_id uuid not null references public.carty_shared_lists(id) on delete cascade,
  item_id text not null,
  position integer not null check (position>=0),
  data jsonb not null check (carty_private.valid_shared_item(data) and data->>'id'=item_id),
  revision bigint not null check (revision>0),
  primary key(list_id,item_id),
  unique(list_id,position) deferrable initially deferred
);
create table public.carty_shared_members (
  list_id uuid not null references public.carty_shared_lists(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('viewer','editor')),
  joined_at timestamptz not null default now(),
  primary key(list_id,user_id)
);
create index carty_shared_members_user_idx on public.carty_shared_members(user_id,list_id);
create table public.carty_shared_invitations (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.carty_shared_lists(id) on delete cascade,
  list_name text not null,
  inviter_name text not null,
  recipient_email text not null check (recipient_email=lower(btrim(recipient_email)) and char_length(recipient_email)<=254),
  role text not null check (role in ('viewer','editor')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now()+interval '7 days'),
  accepted_by uuid references auth.users(id) on delete cascade,
  accepted_at timestamptz,
  revoked_at timestamptz,
  delivery_status text not null default 'in_app' check (delivery_status in ('in_app','sent','failed'))
);
create index carty_shared_invitations_list_idx on public.carty_shared_invitations(list_id,created_at desc);
create index carty_shared_invitations_email_idx on public.carty_shared_invitations(recipient_email)
  where accepted_at is null and revoked_at is null;
create unique index carty_shared_invitations_pending_idx on public.carty_shared_invitations(list_id,recipient_email)
  where accepted_at is null and revoked_at is null;

create function carty_private.verified_email() returns text
language sql stable security definer set search_path = '' as $$
  select lower(btrim(email)) from auth.users where id=(select auth.uid()) and email_confirmed_at is not null
$$;
create function carty_private.shared_role(p_list uuid) returns text
language sql stable security definer set search_path = '' as $$
  select case when l.owner_id=(select auth.uid()) then 'owner' else
    (select role from public.carty_shared_members m where m.list_id=l.id and m.user_id=(select auth.uid())) end
  from public.carty_shared_lists l where l.id=p_list and exists(select 1 from auth.users where id=(select auth.uid()))
$$;
create function carty_private.shared_list_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select l.id from public.carty_shared_lists l where l.owner_id=(select auth.uid())
    and exists(select 1 from auth.users where id=(select auth.uid()))
  union select m.list_id from public.carty_shared_members m where m.user_id=(select auth.uid())
    and exists(select 1 from auth.users where id=(select auth.uid()))
$$;
revoke all on function carty_private.verified_email(), carty_private.shared_role(uuid), carty_private.shared_list_ids() from public, anon, authenticated;
grant execute on function carty_private.verified_email(), carty_private.shared_role(uuid), carty_private.shared_list_ids() to authenticated;
alter table public.carty_shared_lists enable row level security;
alter table public.carty_shared_items enable row level security;
alter table public.carty_shared_members enable row level security;
alter table public.carty_shared_invitations enable row level security;
revoke all on public.carty_shared_lists,public.carty_shared_items,public.carty_shared_members,public.carty_shared_invitations from public,anon,authenticated;
grant select on public.carty_shared_lists,public.carty_shared_items,public.carty_shared_members,public.carty_shared_invitations to authenticated;
create policy "Read accessible shared lists" on public.carty_shared_lists for select to authenticated
  using(id in (select carty_private.shared_list_ids()));
create policy "Read accessible shared items" on public.carty_shared_items for select to authenticated
  using(list_id in (select carty_private.shared_list_ids()));
create policy "Read own membership or manage roster" on public.carty_shared_members for select to authenticated
  using(user_id=(select auth.uid()) or carty_private.shared_role(list_id)='owner');
create policy "Read owned or addressed invitations" on public.carty_shared_invitations for select to authenticated
  using(carty_private.shared_role(list_id)='owner' or
    (recipient_email=(select carty_private.verified_email()) and accepted_at is null and revoked_at is null and expires_at>now()));

-- One narrow API, with explicit authorisation per action. UUIDs supplied by the
-- client identify resources only; ownership always comes from auth.uid().
create function carty_private.shared_action(p_action text,p_args jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare caller uuid := auth.uid(); email text := carty_private.verified_email(); list uuid;
  access text; header public.carty_shared_lists; invitation public.carty_shared_invitations;
  target uuid; requested_role text; supplied_items jsonb; item jsonb; ordinal bigint; next_revision bigint;
begin
  if caller is null or email is null then raise exception 'Sign in with a verified email' using errcode='42501'; end if;
  if jsonb_typeof(p_args) is distinct from 'object' then raise exception 'Invalid arguments' using errcode='22023'; end if;
  if p_action in ('accept','decline','revoke') then
    select * into invitation from public.carty_shared_invitations where id=(p_args->>'invitationId')::uuid;
    if not found then raise exception 'Invitation unavailable' using errcode='42501'; end if;
    -- List lock precedes invitation-row locks in every mutation, including
    -- accept/revoke, to avoid inverted lock ordering during concurrent actions.
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(invitation.list_id::text,1));
    select * into invitation from public.carty_shared_invitations where id=(p_args->>'invitationId')::uuid for update;
    if not found then raise exception 'Invitation unavailable' using errcode='42501'; end if;
    if p_action='revoke' then
      if carty_private.shared_role(invitation.list_id) is distinct from 'owner' then raise exception 'Owner permission required' using errcode='42501'; end if;
      update public.carty_shared_invitations set revoked_at=now() where id=invitation.id and accepted_at is null;
      return jsonb_build_object('ok',true);
    end if;
    if invitation.recipient_email<>email or invitation.accepted_at is not null or invitation.revoked_at is not null or invitation.expires_at<=now() then
      raise exception 'Invitation unavailable' using errcode='42501'; end if;
    if p_action='decline' then
      update public.carty_shared_invitations set revoked_at=now() where id=invitation.id;
    else
      -- Serialize acceptance with owner/member changes and list deletion.
      if not exists(select 1 from public.carty_shared_lists where id=invitation.list_id) then
        raise exception 'List unavailable' using errcode='42501'; end if;
      insert into public.carty_shared_members(list_id,user_id,role) values(invitation.list_id,caller,invitation.role)
        on conflict(list_id,user_id) do update set role=excluded.role;
      update public.carty_shared_invitations set accepted_by=caller,accepted_at=now() where id=invitation.id;
    end if;
    return jsonb_build_object('ok',true,'listId',invitation.list_id);
  end if;
  if p_action='create' then
    list := gen_random_uuid(); access := 'owner';
  else
    list := (p_args->>'listId')::uuid;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(list::text,1));
    access := carty_private.shared_role(list);
    if access is null then raise exception 'List unavailable' using errcode='42501'; end if;
    select * into header from public.carty_shared_lists where id=list;
  end if;
  if p_action in ('create','save') then
    if access not in ('owner','editor') then raise exception 'Editor permission required' using errcode='42501'; end if;
    if p_action='save' and header.revision is distinct from (p_args->>'expectedRevision')::bigint then
      return jsonb_build_object('conflict',true);
    end if;
    supplied_items := p_args->'items';
    if jsonb_typeof(supplied_items) is distinct from 'array' or jsonb_array_length(supplied_items)>1000
      or jsonb_typeof(p_args->'name') is distinct from 'string' or char_length(btrim(p_args->>'name')) not between 1 and 60
      or jsonb_typeof(p_args->'isPlanning') is distinct from 'boolean'
      or not (p_args ? 'budgetPence') or
      (p_args->'budgetPence'<>'null'::jsonb and (jsonb_typeof(p_args->'budgetPence')<>'number' or p_args->>'budgetPence' !~ '^[1-9][0-9]*$')) then
      raise exception 'Invalid shared list' using errcode='22023'; end if;
    if exists(select 1 from jsonb_array_elements(supplied_items) x where not carty_private.valid_shared_item(x.value))
      or (select count(distinct x.value->>'id') from jsonb_array_elements(supplied_items) x)<>jsonb_array_length(supplied_items) then
      raise exception 'Invalid shared product' using errcode='22023'; end if;
    next_revision := case when p_action='create' then 1 else header.revision+1 end;
    if p_action='create' then
      insert into public.carty_shared_lists(id,owner_id,name,budget_pence,is_planning)
        values(list,caller,btrim(p_args->>'name'),(p_args->>'budgetPence')::bigint,(p_args->>'isPlanning')::boolean);
    else
      update public.carty_shared_lists set name=btrim(p_args->>'name'),budget_pence=(p_args->>'budgetPence')::bigint,
        is_planning=(p_args->>'isPlanning')::boolean,revision=next_revision,updated_at=now() where id=list;
    end if;
    delete from public.carty_shared_items where list_id=list and item_id not in
      (select x.value->>'id' from jsonb_array_elements(supplied_items) x);
    insert into public.carty_shared_items(list_id,item_id,position,data,revision)
      select list,x.value->>'id',(x.ordinality-1)::integer,x.value,next_revision from jsonb_array_elements(supplied_items) with ordinality x
      on conflict(list_id,item_id) do update set position=excluded.position,data=excluded.data,revision=excluded.revision
        where (carty_shared_items.position,carty_shared_items.data) is distinct from (excluded.position,excluded.data);
    return jsonb_build_object('listId',list,'revision',next_revision);
  elsif p_action='invite' then
    if access<>'owner' then raise exception 'Owner permission required' using errcode='42501'; end if;
    requested_role := p_args->>'role';
    if requested_role is null or requested_role not in ('viewer','editor') or
      coalesce(p_args->>'email','') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or char_length(p_args->>'email')>254 then
      raise exception 'Invalid invitation' using errcode='22023'; end if;
    if lower(btrim(p_args->>'email'))=email then raise exception 'You already own this list' using errcode='22023'; end if;
    if (select count(*) from public.carty_shared_invitations where list_id=list and created_at>now()-interval '1 hour')>=20 then
      raise exception 'Invitation limit reached; try later' using errcode='22023'; end if;
    update public.carty_shared_invitations set revoked_at=now() where list_id=list and recipient_email=lower(btrim(p_args->>'email'))
      and accepted_at is null and revoked_at is null;
    insert into public.carty_shared_invitations(list_id,list_name,inviter_name,recipient_email,role)
      values(list,header.name,coalesce(nullif((select display_name from public.carty_profiles where user_id=caller),''),email),
        lower(btrim(p_args->>'email')),requested_role) returning * into invitation;
    return jsonb_build_object('invitationId',invitation.id,'deliveryStatus','in_app');
  elsif p_action='member' then
    if access<>'owner' then raise exception 'Owner permission required' using errcode='42501'; end if;
    target := (p_args->>'userId')::uuid; requested_role := p_args->>'role';
    if target=header.owner_id or target is null or (requested_role is not null and requested_role not in ('viewer','editor')) then
      raise exception 'Invalid membership change' using errcode='22023'; end if;
    if requested_role is null then delete from public.carty_shared_members where list_id=list and user_id=target;
    else update public.carty_shared_members set role=requested_role where list_id=list and user_id=target;
    end if;
    -- A pending invitation must not restore access after explicit revocation.
    update public.carty_shared_invitations set revoked_at=now() where list_id=list and accepted_at is null and revoked_at is null
      and recipient_email=(select lower(btrim(u.email)) from auth.users u where u.id=target);
    return jsonb_build_object('ok',true);
  elsif p_action='leave' then
    if access='owner' then raise exception 'Owners must delete their list' using errcode='22023'; end if;
    delete from public.carty_shared_members where list_id=list and user_id=caller;
    update public.carty_shared_invitations set revoked_at=now() where list_id=list and recipient_email=email
      and accepted_at is null and revoked_at is null;
    return jsonb_build_object('ok',true);
  elsif p_action='delete' then
    if access<>'owner' then raise exception 'Owner permission required' using errcode='42501'; end if;
    if header.revision is distinct from (p_args->>'expectedRevision')::bigint then return jsonb_build_object('conflict',true); end if;
    delete from public.carty_shared_lists where id=list;
    return jsonb_build_object('ok',true);
  end if;
  raise exception 'Unsupported sharing action' using errcode='22023';
end $$;
revoke all on function carty_private.shared_action(text,jsonb) from public,anon,authenticated;
grant execute on function carty_private.shared_action(text,jsonb) to authenticated;
create function public.carty_shared_action(p_action text,p_args jsonb) returns jsonb
language sql security invoker set search_path = '' as $$ select carty_private.shared_action(p_action,p_args) $$;
revoke all on function public.carty_shared_action(text,jsonb) from public,anon;
grant execute on function public.carty_shared_action(text,jsonb) to authenticated;
