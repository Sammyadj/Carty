-- Exercise every migrated record kind and growth beyond the old 2 MiB blob.
-- Synthetic fixtures only. The entire transaction rolls back.
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-00000000cb03','carty-record-growth@example.invalid');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000cb03","role":"authenticated"}',true);
do $test$
declare item jsonb := '{"id":"milk","name":"Milk","quantity":1,"plannedQuantity":2,"unitPricePence":150,"estimatedUnitPricePence":140,"priceConfirmed":true,"category":"dairyAndEggs"}';
  snapshot jsonb; h public.carty_cloud_heads; meta jsonb; changes jsonb; removals jsonb;
  n integer; bytes bigint; changed jsonb;
begin
  snapshot := jsonb_build_object('version',3,'activeListId',null,'budgetPence',5000,'isPlanning',false,
    'items',jsonb_build_array(item),
    'savedLists',jsonb_build_array(jsonb_build_object('id','weekly','name','Weekly','items',jsonb_build_array(item),
      'budgetPence',5000,'savedAt','2026-10-28T00:00:00Z','isPlanning',false,'favourite',true,'archived',true)),
    'history',jsonb_build_array(jsonb_build_object('id','trip','name','Trip','items',jsonb_build_array(item),
      'plannedItems',jsonb_build_array(item),'budgetPence',5000,'completedAt','2026-10-28T00:00:00Z',
      'currency','GBP','favourite',true,'archived',false)),
    'productPreferences','[{"name":"Milk","unitPricePence":150,"category":"dairyAndEggs","favourite":true,"hidden":false,"lessOften":true,"updatedAt":"2026-10-28T00:00:00Z"}]'::jsonb);
  perform public.carty_save_workspace(0,snapshot);
  select * into h from public.carty_bootstrap_records();
  select count(distinct kind) into n from public.carty_cloud_records;
  if h.record_count <> 7 or n <> 7 then raise exception 'Nested migration omitted records'; end if;
  if (select data from public.carty_cloud_records where kind='trips') <>
    jsonb_build_object('fields',(snapshot->'history'->0) - 'items' - 'plannedItems','hasPlan',true) then
    raise exception 'Trip metadata lost during migration';
  end if;
  if (select data from public.carty_cloud_records where kind='tripPlanItems') <> item
    or (select data from public.carty_cloud_records where kind='listItems') <> item
    or (select data->>'archived' from public.carty_cloud_records where kind='lists') <> 'true'
    or (select data->>'lessOften' from public.carty_cloud_records where kind='preferences') <> 'true' then
    raise exception 'Nested plan or preference fields changed';
  end if;
  meta := h.metadata;
  select jsonb_agg(jsonb_build_object('kind',kind,'parent_id',parent_id,'record_id',record_id))
    into removals from public.carty_cloud_records;
  select jsonb_agg(jsonb_build_object('kind','items','parent_id','','record_id','product-'||g,'position',g,
    'data',jsonb_build_object('id','product-'||g,'name',repeat('x',110),'quantity',0,'plannedQuantity',2,
      'unitPricePence',150,'estimatedUnitPricePence',140,'priceConfirmed',false,'category','other')))
    into changes from generate_series(0,9999) g;
  select * into h from public.carty_save_record_delta(2,1,meta,changes,removals);
  select sum(octet_length(data::text)) into bytes from public.carty_cloud_records;
  if h.record_count <> 10000 or bytes <= 2097152 then raise exception 'Growth test did not exceed old blob capacity'; end if;
  select jsonb_set(data,'{unitPricePence}','175') into changed from public.carty_cloud_records where record_id='product-17';
  select * into h from public.carty_save_record_delta(2,2,meta,
    jsonb_build_array(jsonb_build_object('kind','items','parent_id','','record_id','product-17','position',17,'data',changed)),'[]');
  select count(*) into n from public.carty_cloud_records where revision=3;
  if n <> 1 or h.revision <> 3 or h.record_count <> 10000 then raise exception 'One edit rewrote unrelated records'; end if;
end $test$;
rollback;
select 'Carty nested migration and 10,000-record growth/delta checks passed; fixtures rolled back.' as result;
