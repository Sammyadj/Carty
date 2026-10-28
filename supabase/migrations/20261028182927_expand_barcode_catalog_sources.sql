-- Add open catalog attribution without changing membership or item checks.
create or replace function carty_private.valid_shared_item(item jsonb) returns boolean
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
      coalesce(product->>'source','') not in ('manual','openFoodFacts','upcitemdb','openBeautyFacts','openPetFoodFacts','openProductsFacts') then return false; end if;
    if product ? 'fromOpenFoodFacts' and jsonb_typeof(product->'fromOpenFoodFacts') not in ('boolean','null') then return false; end if;
  end if;
  return true;
exception when others then return false;
end $$;
revoke all on function carty_private.valid_shared_item(jsonb) from public, anon, authenticated;

