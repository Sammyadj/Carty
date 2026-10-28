# Private cloud records: protocol 2

The active Carty project has the `structured_cloud_records` migration applied.
Its recorded version is `20261028063541`, matching the repository migration.
This replaces the original blob path for accounts opened by the updated app.
No user data was deleted and no test fixtures remain.

## Data and sync

`carty_cloud_heads` stores an account's revision, portable root metadata, protocol
version, record count, and update time. `carty_cloud_records` stores basket items,
saved-list metadata/items, trip metadata/picked items/original plans, and product
choices as individual rows. Stable IDs and parent IDs preserve relationships.
Each row has the revision of its last change. Composite keys support account
filtering and stable pagination; collection positions preserve display order.

The app downloads 500 records per request and checks the head again afterward.
If the head changed, it retries the download instead of accepting mixed pages.
It validates every reconstructed workspace before caching or publishing it.
Missing, corrupt, foreign, or unsupported responses leave existing device data
available. Each HTTP request checks that the original account is still active.

Uploads compare the desired records with the accepted base and send changed
rows, deleted keys, and root metadata. The database serialises writes per owner,
checks the expected head revision, and applies the delta in one transaction.
Invalid parent links/order or failed constraints roll back the revision and
rows together. Unchanged rows retain their previous revisions.

Conflict resolution still asks the shopper to review competing **whole
workspaces**. Individual rows do not imply automatic merging or household
collaboration. Local saves finish before uploads, and failed local saves block
cloud sync as before.

## Existing accounts and older clients

The first protocol-2 fetch calls `carty_bootstrap_records()`. If there is an
original `carty_workspaces` row, the server decomposes it transactionally while
retaining its revision, full plan/history/preferences, and original snapshot.
The operation is idempotent. A failed migration preserves the original and
does not publish a partial new copy.

The original save function continues working for accounts that have not
upgraded. Once a protocol-2 head exists, it rejects old saves with an update
requirement. Old clients may still read the frozen original snapshot, so update
every device used with that account. Old and new writes share the same owner
lock to prevent a first-migration race from losing an intervening save.

The app keeps portable shopping snapshot format version 3; cloud **protocol 2**
is a separate compatibility gate. Backup restore normalizes older valid
shopping snapshots before syncing through the new protocol.

## Authorisation and limits

Both exposed tables have RLS and explicit authenticated SELECT grants scoped to
`auth.uid()`. Clients have no direct INSERT/UPDATE/DELETE grants. Public RPC
wrappers run as invokers; the narrowly granted mutation functions live in the
unexposed `carty_private` schema, use an empty search path, derive ownership from
the verified caller, and reject deleted users. No service-role key is in the app.

The existing account-delete and legacy-save functions retain their two intentional
[authenticated SECURITY DEFINER advisor warnings](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
The new migration adds no security/performance advisor findings. Shared-list
permissions will be separate from these private-workspace policies.

There is no 2 MiB cap on an upgraded account's combined records. A record and
root metadata are each bounded at 64 KiB; one atomic patch is limited to 20,000
upserts plus deletions. Very large initial imports can exceed that patch limit
and remain local. Export a backup before reorganising them. Full workspace
hydration and diffing still happen in memory, so further incremental loading and
staged import work would be needed for much larger histories. Provider storage,
network, and account quotas still apply.

## Verification

- Full Flutter regression suite: **280 tests pass**, analysis clean.
- Adapter tests: 1,050 records across three pages; a single edit sends one row;
  deletion/metadata-only deltas; restarted clients; stale revisions; changed heads
  during download; repeated concurrent changes; incomplete downloads; late
  responses after account switching; foreign responses and anonymous access.
- Live `structured_records_security.sql`: migration/idempotence, old-writer
  rejection, owner isolation, denied direct writes, stale CAS, invalid-patch
  rollback, orphan rejection, deletion cascades, and deleted-token rejection.
- Live `structured_records_growth.sql`: all seven record kinds preserve nested
  plan/category/archive/preference fields; 10,000 records exceed the previous
  2 MiB capacity; one edit changes only one record's revision.
- The original `phase_one_security.sql` still passes for unupgraded accounts.
  All database fixtures roll back; a follow-up query found no fixture accounts.

These tests do not replace actual email delivery, offline/conflicting use on
two physical devices, or release signing. Native iOS Simulator and Android
Debug builds passed for the storage/file-picker milestone; no additional native
dependencies were added for this adapter.
