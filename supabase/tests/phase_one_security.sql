-- Synthetic, disposable fixtures only. The entire test rolls back.
begin;
insert into auth.users (id, email) values
 ('00000000-0000-4000-8000-00000000ca01', 'carty-test-a@example.invalid'),
 ('00000000-0000-4000-8000-00000000ca02', 'carty-test-b@example.invalid');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000ca01","role":"authenticated"}', true);
do $test$
declare n integer; rev bigint;
  snapshot jsonb := '{"version":3,"activeListId":null,"budgetPence":null,"items":[],"savedLists":[],"history":[]}';
begin
  insert into public.carty_profiles(user_id, display_name)
    values(auth.uid(), 'Test A');
  select count(*), max(revision) into n, rev from public.carty_save_workspace(0, snapshot);
  if n != 1 or rev != 1 then raise exception 'Initial revision failed'; end if;
  select count(*) into n from public.carty_save_workspace(0, snapshot);
  if n != 0 then raise exception 'Stale create overwrote data'; end if;
  select max(revision) into rev from public.carty_save_workspace(1, snapshot);
  if rev != 2 then raise exception 'Revision compare-and-set failed'; end if;
  begin
    insert into public.carty_profiles(user_id, display_name)
      values('00000000-0000-4000-8000-00000000ca02', 'Forbidden');
    raise exception 'Cross-account profile insert was allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.carty_save_workspace(2, '{}'::jsonb);
    raise exception 'Invalid snapshot was accepted';
  exception when check_violation then null;
  end;
end $test$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000ca02","role":"authenticated"}', true);
do $test$
declare n integer;
begin
  select count(*) into n from public.carty_profiles;
  if n != 0 then raise exception 'Profile data crossed accounts'; end if;
  select count(*) into n from public.carty_workspaces;
  if n != 0 then raise exception 'Workspace data crossed accounts'; end if;
  update public.carty_profiles set display_name = 'Forbidden'
    where user_id = '00000000-0000-4000-8000-00000000ca01';
  get diagnostics n = row_count;
  if n != 0 then raise exception 'Cross-account profile update allowed'; end if;
  insert into public.carty_profiles(user_id, display_name) values(auth.uid(), 'Test B');
  perform public.carty_save_workspace(0, '{"version":3,"items":[],"savedLists":[],"history":[]}');
end $test$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000ca01","role":"authenticated"}', true);
select public.carty_delete_my_account();
reset role;
do $test$
begin
  if exists(select 1 from auth.users where id = '00000000-0000-4000-8000-00000000ca01') then
    raise exception 'Account deletion failed';
  end if;
  if exists(select 1 from public.carty_workspaces where user_id = '00000000-0000-4000-8000-00000000ca01') then
    raise exception 'Private workspace did not cascade';
  end if;
  if exists(select 1 from public.carty_profiles where user_id = '00000000-0000-4000-8000-00000000ca01') then
    raise exception 'Profile did not cascade';
  end if;
  if not exists(select 1 from public.carty_workspaces where user_id = '00000000-0000-4000-8000-00000000ca02') then
    raise exception 'Another account was affected';
  end if;
  if has_table_privilege('anon', 'public.carty_workspaces', 'select')
    or has_function_privilege('anon', 'public.carty_save_workspace(bigint,jsonb)', 'execute')
    or has_function_privilege('anon', 'public.carty_delete_my_account()', 'execute') then
    raise exception 'Anonymous access was granted';
  end if;
end $test$;
rollback;
select 'All Carty database isolation, revision, validation and deletion tests passed; fixtures rolled back.' as result;

