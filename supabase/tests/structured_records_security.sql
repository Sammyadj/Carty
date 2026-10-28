-- Run after structured_cloud_records. Synthetic fixtures; no emails; rollback.
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-00000000cb01','carty-record-a@example.invalid'),
 ('00000000-0000-4000-8000-00000000cb02','carty-record-b@example.invalid');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cb01","role":"authenticated"}',true);
do $test$
declare snapshot jsonb := '{"version":3,"activeListId":null,"budgetPence":5000,"isPlanning":true,
  "items":[{"id":"milk","name":"Milk","quantity":0,"plannedQuantity":2,"unitPricePence":150,"estimatedUnitPricePence":140,"priceConfirmed":false,"category":"dairyAndEggs"}],
  "savedLists":[],"history":[],"productPreferences":[]}';
  h public.carty_cloud_heads; n integer; meta jsonb; original_revision bigint;
begin
  perform public.carty_save_workspace(0,snapshot);
  select * into h from public.carty_bootstrap_records();
  if h.revision <> 1 or h.record_count <> 1 or h.metadata->'fields'->>'isPlanning' <> 'true' then
    raise exception 'Legacy migration lost metadata';
  end if;
  if (select data from public.carty_cloud_records where kind='items' and record_id='milk') <> snapshot->'items'->0 then
    raise exception 'Legacy migration lost item fields';
  end if;
  select count(*) into n from public.carty_bootstrap_records();
  if n <> 1 or (select count(*) from public.carty_cloud_records) <> 1 then raise exception 'Migration was not idempotent'; end if;
  if (select w.snapshot from public.carty_workspaces w) <> snapshot then raise exception 'Legacy source changed'; end if;
  begin
    perform public.carty_save_workspace(1,snapshot);
    raise exception 'Old writer replaced upgraded data';
  exception when invalid_parameter_value then null;
  end;
  meta := h.metadata;
  select * into h from public.carty_save_record_delta(2,1,meta,
    '[{"kind":"items","parent_id":"","record_id":"milk","position":0,"data":{"id":"milk","name":"Milk","quantity":1,"unitPricePence":175}}]', '[]');
  if h.revision <> 2 or (select revision from public.carty_cloud_records where record_id='milk') <> 2 then
    raise exception 'Delta revision failed';
  end if;
  select count(*) into n from public.carty_save_record_delta(2,1,meta,'[]','[]');
  if n <> 0 then raise exception 'Stale delta was accepted'; end if;
  begin
    perform public.carty_save_record_delta(1,2,meta,'[]','[]');
    raise exception 'Unsupported protocol accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.carty_save_record_delta(2,2,meta,
      '[{"kind":"items","parent_id":"","record_id":"bad","position":5,"data":{"id":"bad"}}]','[]');
    raise exception 'Invalid ordering accepted';
  exception when check_violation then null;
  end;
  if (select revision from public.carty_cloud_heads) <> 2 then raise exception 'Invalid delta advanced the revision'; end if;
  if exists(select 1 from public.carty_cloud_records where record_id='bad') then raise exception 'Partial rows survived rollback'; end if;
  begin
    perform public.carty_save_record_delta(2,2,meta,
      '[{"kind":"listItems","parent_id":"missing","record_id":"orphan","position":0,"data":{"id":"orphan"}}]','[]');
    raise exception 'Orphan child accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.carty_cloud_records(user_id,kind,parent_id,record_id,position,revision,data)
      values(auth.uid(),'items','','direct',1,2,'{"id":"direct"}');
    raise exception 'Direct table write bypassed CAS';
  exception when insufficient_privilege then null;
  end;
  select * into h from public.carty_save_record_delta(2,2,meta,'[]',
    '[{"kind":"items","parent_id":"","record_id":"milk"}]');
  if h.revision <> 3 or h.record_count <> 0 then raise exception 'Deletion did not remove the record'; end if;
end $test$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cb02","role":"authenticated"}',true);
do $test$
declare h public.carty_cloud_heads;
begin
  if exists(select 1 from public.carty_cloud_heads) or exists(select 1 from public.carty_cloud_records) then
    raise exception 'Cloud records crossed accounts';
  end if;
  select * into h from public.carty_save_record_delta(2,0,
    '{"fields":{"version":3,"activeListId":null,"budgetPence":null},"collections":["items","savedLists","history"]}',
    '[{"kind":"items","parent_id":"","record_id":"other","position":0,"data":{"id":"other","name":"Other"}}]','[]');
  if h.user_id <> auth.uid() or h.revision <> 1 then raise exception 'New account ownership failed'; end if;
end $test$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cb01","role":"authenticated"}',true);
select public.carty_delete_my_account();
do $test$
begin
  if exists(select 1 from public.carty_cloud_heads) or exists(select 1 from public.carty_cloud_records) then
    raise exception 'Deleted user retains data access';
  end if;
  begin
    perform public.carty_save_record_delta(2,0,'{}','[]','[]');
    raise exception 'Deleted-user token created a workspace';
  exception when insufficient_privilege then null;
  end;
end $test$;
reset role;
do $test$
begin
  if not exists(select 1 from public.carty_cloud_heads where user_id='00000000-0000-4000-8000-00000000cb02') then
    raise exception 'Account deletion affected another account';
  end if;
  if has_table_privilege('anon','public.carty_cloud_heads','select')
    or has_table_privilege('anon','public.carty_cloud_records','select')
    or has_function_privilege('anon','public.carty_bootstrap_records()','execute')
    or has_function_privilege('anon','public.carty_save_record_delta(integer,bigint,jsonb,jsonb,jsonb)','execute') then
    raise exception 'Anonymous access exposed';
  end if;
end $test$;
rollback;
select 'Carty cloud record migration, delta CAS, isolation, rollback and deletion checks passed; fixtures rolled back.' as result;
