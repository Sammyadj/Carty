-- Rollback-only fixtures. These tests send no invitations or emails externally.
begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000cc01','carty-owner@example.invalid',now(),'{}'),
 ('00000000-0000-4000-8000-00000000cc02','carty-editor@example.invalid',now(),'{}'),
 ('00000000-0000-4000-8000-00000000cc03','carty-viewer@example.invalid',now(),'{}'),
 ('00000000-0000-4000-8000-00000000cc04','carty-outsider@example.invalid',now(),'{"role":"owner"}'),
 ('00000000-0000-4000-8000-00000000cc05','carty-unverified@example.invalid',null,'{}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cc01","role":"authenticated"}',true);
do $test$
declare result jsonb; owned_list uuid; invitation uuid; bad jsonb; original_item jsonb;
begin
  result := public.carty_shared_action('create','{"name":"Family shop","budgetPence":5000,"isPlanning":true,"items":[{"id":"milk","name":"Milk","quantity":0,"plannedQuantity":2,"unitPricePence":150,"estimatedUnitPricePence":140,"priceConfirmed":false,"category":"dairyAndEggs","product":{"barcode":"3017620422003","name":"Milk","source":"manual"}}]}');
  owned_list := (result->>'listId')::uuid;
  perform set_config('carty.test.list',owned_list::text,true);
  result := public.carty_shared_action('invite',jsonb_build_object('listId',owned_list,'email','CARTY-EDITOR@EXAMPLE.INVALID','role','editor'));
  perform set_config('carty.test.editor',result->>'invitationId',true);
  if result->>'deliveryStatus'<>'in_app' then raise exception 'Undelivered invitation claimed sent'; end if;
  result := public.carty_shared_action('invite',jsonb_build_object('listId',owned_list,'email','carty-viewer@example.invalid','role','viewer'));
  perform set_config('carty.test.viewer',result->>'invitationId',true);
  result := public.carty_shared_action('invite',jsonb_build_object('listId',owned_list,'email','carty-unverified@example.invalid','role','editor'));
  perform set_config('carty.test.unverified',result->>'invitationId',true);
  begin
    perform public.carty_shared_action('create','{"name":"Bad item","budgetPence":null,"isPlanning":true,"items":[{"id":"bad","name":"Bad","quantity":0,"plannedQuantity":2,"unitPricePence":150,"estimatedUnitPricePence":140,"priceConfirmed":false,"category":"other","product":{"barcode":"00000001","name":"Bad","source":"manual"}}]}');
    raise exception 'Malformed barcode was accepted';
  exception when invalid_parameter_value then null;
  end;
  select i.data into original_item from public.carty_shared_items i where i.list_id=owned_list;
  for bad in select value from jsonb_array_elements('[{"quantity":10000},{"unitPricePence":0},{"estimatedUnitPricePence":null},{"category":"unknown"}]') loop
    begin
      perform public.carty_shared_action('create',jsonb_build_object('name','Invalid','budgetPence',null,'isPlanning',true,'items',jsonb_build_array(original_item||bad)));
      raise exception 'Invalid product fields were accepted';
    exception when invalid_parameter_value then null;
    end;
  end loop;
  if (select count(*) from public.carty_shared_lists)<>1 then raise exception 'Invalid list left partial data'; end if;
end $test$;

-- User metadata and a spoofed email claim cannot confer membership or access.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cc04","role":"authenticated","email":"carty-editor@example.invalid","user_metadata":{"role":"owner"}}',true);
do $test$
begin
  if exists(select 1 from public.carty_shared_lists) or exists(select 1 from public.carty_shared_items)
    or exists(select 1 from public.carty_shared_members) or exists(select 1 from public.carty_shared_invitations) then
    raise exception 'Outsider read household data'; end if;
  begin
    perform public.carty_shared_action('accept',jsonb_build_object('invitationId',current_setting('carty.test.editor')));
    raise exception 'Wrong email accepted invitation';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.carty_shared_action('invite',jsonb_build_object('listId',current_setting('carty.test.list'),'email','outsider@example.invalid','role','editor'));
    raise exception 'Outsider created invitation';
  exception when insufficient_privilege then null;
  end;
end $test$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cc02","role":"authenticated"}',true);
do $test$
declare result jsonb; list_id uuid := current_setting('carty.test.list')::uuid;
begin
  if (select count(*) from public.carty_shared_invitations)<>1 then raise exception 'Recipient saw another invitation'; end if;
  perform public.carty_shared_action('accept',jsonb_build_object('invitationId',current_setting('carty.test.editor')));
  begin
    perform public.carty_shared_action('accept',jsonb_build_object('invitationId',current_setting('carty.test.editor')));
    raise exception 'Accepted invitation was replayed';
  exception when insufficient_privilege then null;
  end;
  if (select count(*) from public.carty_shared_lists)<>1 or (select count(*) from public.carty_shared_items)<>1 then raise exception 'Accepted editor cannot read'; end if;
  result := public.carty_shared_action('save',jsonb_build_object('listId',list_id,'expectedRevision',1,'name','Family shop','budgetPence',5000,'isPlanning',false,'items',
    '[{"id":"milk","name":"Milk","quantity":1,"plannedQuantity":2,"unitPricePence":175,"estimatedUnitPricePence":140,"priceConfirmed":true,"category":"dairyAndEggs"}]'::jsonb));
  if result->>'revision'<>'2' then raise exception 'Editor cannot update picked quantity'; end if;
  result := public.carty_shared_action('save',jsonb_build_object('listId',list_id,'expectedRevision',1));
  if result->>'conflict'<>'true' then raise exception 'Stale editor overwrote list'; end if;
  begin
    perform public.carty_shared_action('member',jsonb_build_object('listId',list_id,'userId','00000000-0000-4000-8000-00000000cc03','role','editor'));
    raise exception 'Editor changed membership';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.carty_shared_lists where id=list_id;
    raise exception 'Direct delete bypassed owner permission';
  exception when insufficient_privilege then null;
  end;
end $test$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cc03","role":"authenticated"}',true);
do $test$
begin
  perform public.carty_shared_action('accept',jsonb_build_object('invitationId',current_setting('carty.test.viewer')));
  if (select count(*) from public.carty_shared_items)<>1 then raise exception 'Viewer cannot read items'; end if;
  begin
    perform public.carty_shared_action('save',jsonb_build_object('listId',current_setting('carty.test.list'),'expectedRevision',2));
    raise exception 'Viewer changed items';
  exception when insufficient_privilege then null;
  end;
end $test$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cc05","role":"authenticated","email_confirmed_at":"2026-10-28T00:00:00Z"}',true);
do $test$
begin
  if exists(select 1 from public.carty_shared_invitations) then raise exception 'Unverified email read invitation'; end if;
  begin
    perform public.carty_shared_action('accept',jsonb_build_object('invitationId',current_setting('carty.test.unverified')));
    raise exception 'Unverified email accepted invitation';
  exception when insufficient_privilege then null;
  end;
end $test$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cc01","role":"authenticated"}',true);
do $test$
declare list_id uuid := current_setting('carty.test.list')::uuid; result jsonb;
begin
  if (select count(*) from public.carty_shared_members)<>2 then raise exception 'Owner cannot manage roster'; end if;
  perform public.carty_shared_action('member',jsonb_build_object('listId',list_id,'userId','00000000-0000-4000-8000-00000000cc02','role','viewer'));
  perform public.carty_shared_action('member',jsonb_build_object('listId',list_id,'userId','00000000-0000-4000-8000-00000000cc03','role',null));
  result := public.carty_shared_action('invite',jsonb_build_object('listId',list_id,'email','carty-outsider@example.invalid','role','viewer'));
  perform set_config('carty.test.revoked',result->>'invitationId',true);
  perform public.carty_shared_action('revoke',jsonb_build_object('invitationId',result->>'invitationId'));
end $test$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cc02","role":"authenticated"}',true);
do $test$
begin
  begin
    perform public.carty_shared_action('save',jsonb_build_object('listId',current_setting('carty.test.list'),'expectedRevision',2));
    raise exception 'Downgraded editor still changed items';
  exception when insufficient_privilege then null;
  end;
  perform public.carty_shared_action('leave',jsonb_build_object('listId',current_setting('carty.test.list')));
  if exists(select 1 from public.carty_shared_lists) then raise exception 'Leaving retained access'; end if;
end $test$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cc03","role":"authenticated"}',true);
do $test$
declare result jsonb;
begin
  if exists(select 1 from public.carty_shared_lists) or exists(select 1 from public.carty_shared_items) then raise exception 'Revocation retained read access'; end if;
  begin
    perform public.carty_shared_action('save',jsonb_build_object('listId',current_setting('carty.test.list'),'expectedRevision',2));
    raise exception 'Revoked member still wrote';
  exception when insufficient_privilege then null;
  end;
  result := public.carty_shared_action('create','{"name":"Other household","budgetPence":null,"isPlanning":true,"items":[]}');
  perform set_config('carty.test.other',result->>'listId',true);
end $test$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cc04","role":"authenticated"}',true);
do $test$
begin
  begin
    perform public.carty_shared_action('accept',jsonb_build_object('invitationId',current_setting('carty.test.revoked')));
    raise exception 'Revoked invitation was accepted';
  exception when insufficient_privilege then null;
  end;
end $test$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cc01","role":"authenticated"}',true);
select public.carty_delete_my_account();
do $test$
begin
  begin
    perform public.carty_shared_action('create','{"name":"Deleted owner","budgetPence":null,"isPlanning":true,"items":[]}');
    raise exception 'Deleted-owner token created a shared list';
  exception when insufficient_privilege then null;
  end;
end $test$;
reset role;
do $test$
begin
  if exists(select 1 from public.carty_shared_lists where id=current_setting('carty.test.list')::uuid)
    or exists(select 1 from public.carty_shared_items where list_id=current_setting('carty.test.list')::uuid)
    or exists(select 1 from public.carty_shared_members where list_id=current_setting('carty.test.list')::uuid)
    or exists(select 1 from public.carty_shared_invitations where list_id=current_setting('carty.test.list')::uuid) then
    raise exception 'Owner deletion failed to cascade shared data'; end if;
  if not exists(select 1 from public.carty_shared_lists where id=current_setting('carty.test.other')::uuid) then
    raise exception 'Owner deletion removed another household'; end if;
  if has_table_privilege('anon','public.carty_shared_lists','select') or has_function_privilege('anon','public.carty_shared_action(text,jsonb)','execute') then
    raise exception 'Anonymous sharing access exposed'; end if;
  if has_table_privilege('authenticated','public.carty_shared_members','insert')
    or has_table_privilege('authenticated','public.carty_shared_invitations','update')
    or has_table_privilege('authenticated','public.carty_shared_items','update') then
    raise exception 'Direct sharing writes exposed'; end if;
end $test$;
rollback;
select 'Carty household roles, invitation identity, editor-only writes, revocation, CAS and owner-deletion isolation passed; fixtures rolled back.' as result;
