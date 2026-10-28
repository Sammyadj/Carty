-- Read-only validation probes; no customer rows are changed.
begin;
do $$
declare
  source text;
  item jsonb := '{"id":"sample","name":"Sample","quantity":0,"plannedQuantity":1,"unitPricePence":150,"estimatedUnitPricePence":150,"priceConfirmed":false,"category":"personalCare","product":{"barcode":"3560070791460","name":"Sample","source":"manual"}}';
begin
  foreach source in array array['manual','openFoodFacts','upcitemdb','openBeautyFacts','openPetFoodFacts','openProductsFacts'] loop
    if not carty_private.valid_shared_item(jsonb_set(item,'{product,source}',to_jsonb(source))) then
      raise exception 'Valid source rejected: %',source;
    end if;
  end loop;
  if carty_private.valid_shared_item(jsonb_set(item,'{product,source}','"unknown"')) then
    raise exception 'Unknown source accepted';
  end if;
  if carty_private.valid_shared_item(jsonb_set(item,'{product,barcode}','"3560070791461"')) then
    raise exception 'Invalid barcode accepted';
  end if;
  if carty_private.valid_shared_item(jsonb_set(item,'{quantity}','-1')) then
    raise exception 'Negative quantity accepted';
  end if;
  if has_function_privilege('anon','carty_private.valid_shared_item(jsonb)','execute') or
     has_function_privilege('authenticated','carty_private.valid_shared_item(jsonb)','execute') then
    raise exception 'Private validator exposed';
  end if;
  if (select prosecdef from pg_proc where oid='carty_private.valid_shared_item(jsonb)'::regprocedure) then
    raise exception 'Validator must remain security invoker';
  end if;
end $$;
rollback;
