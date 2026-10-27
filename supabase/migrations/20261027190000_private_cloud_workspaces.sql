-- Private phase-one cloud workspace. No sharing or payment permissions.
create table public.carty_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 60),
  updated_at timestamptz not null default now()
);
create table public.carty_workspaces (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null check (revision > 0),
  snapshot jsonb not null check (
    jsonb_typeof(snapshot) = 'object'
    and snapshot->>'version' = '3'
    and jsonb_typeof(snapshot->'items') = 'array'
    and jsonb_typeof(snapshot->'savedLists') = 'array'
    and jsonb_typeof(snapshot->'history') = 'array'
    and octet_length(snapshot::text) <= 2097152
  ),
  updated_at timestamptz not null default now()
);
alter table public.carty_profiles enable row level security;
alter table public.carty_workspaces enable row level security;
revoke all on public.carty_profiles, public.carty_workspaces from anon;
revoke all on public.carty_profiles, public.carty_workspaces from authenticated;
grant select, insert, update on public.carty_profiles to authenticated;
grant select on public.carty_workspaces to authenticated;
create policy "Read own profile" on public.carty_profiles for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Create own profile" on public.carty_profiles for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Update own profile" on public.carty_profiles for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Read own workspace" on public.carty_workspaces for select to authenticated
  using ((select auth.uid()) = user_id);

-- All writes compare the last seen revision atomically. An empty result is a
-- conflict, never permission to overwrite another device's newer changes.
create function public.carty_save_workspace(p_expected_revision bigint, p_snapshot jsonb)
returns setof public.carty_workspaces
language plpgsql security definer set search_path = ''
as $$
declare owner_id uuid := auth.uid();
begin
  if owner_id is null then
    raise exception 'Sign in before saving' using errcode = '42501';
  end if;
  if p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'Invalid workspace revision' using errcode = '22023';
  end if;
  if p_expected_revision = 0 then
    return query insert into public.carty_workspaces(user_id, revision, snapshot)
      values(owner_id, 1, p_snapshot)
      on conflict (user_id) do nothing returning *;
  else
    return query update public.carty_workspaces
      set snapshot = p_snapshot, revision = revision + 1, updated_at = now()
      where user_id = owner_id and revision = p_expected_revision
      returning *;
  end if;
end;
$$;
revoke all on function public.carty_save_workspace(bigint, jsonb) from public, anon;
grant execute on function public.carty_save_workspace(bigint, jsonb) to authenticated;

-- This function has no user-id argument: a session can delete only its own
-- account. Private data cascades; sharing has deliberately not been introduced.
create function public.carty_delete_my_account()
returns void language plpgsql security definer set search_path = ''
as $$
declare owner_id uuid := auth.uid();
begin
  if owner_id is null then
    raise exception 'Sign in before deleting your account' using errcode = '42501';
  end if;
  delete from auth.users where id = owner_id;
end;
$$;
revoke all on function public.carty_delete_my_account() from public, anon;
grant execute on function public.carty_delete_my_account() to authenticated;

