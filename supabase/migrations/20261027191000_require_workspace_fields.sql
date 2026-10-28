alter table public.carty_workspaces
  drop constraint carty_workspaces_snapshot_check;
alter table public.carty_workspaces
  add constraint carty_workspaces_snapshot_check check (coalesce(
    jsonb_typeof(snapshot) = 'object'
    and snapshot->>'version' = '3'
    and jsonb_typeof(snapshot->'items') = 'array'
    and jsonb_typeof(snapshot->'savedLists') = 'array'
    and jsonb_typeof(snapshot->'history') = 'array'
    and octet_length(snapshot::text) <= 2097152,
    false
  ));

