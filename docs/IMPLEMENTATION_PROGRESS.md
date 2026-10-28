# Carty everyday shopping improvements

This tracks the full implementation requested on 28 October 2026. Each working
milestone includes regression checks and a local commit. Publishing remains a
separate action when authorised.

## Requirements and verification

- [x] Planning and shopping: separate planned quantities/estimated prices from
  picked quantities/confirmed shelf prices; show estimated and picked totals,
  budget remaining, and complete only picked items. Verify migration, restart,
  saved-list continuation, scan merging, and immutable history.
- [x] Grocery categories: editable product classification, category filtering,
  grouped shopping lists, and horizontal product browsing. Verify manual
  overrides, uncategorised products, search combinations, and larger text.
- [x] Personal recommendations: favourites, hide suggestions, suggest less often,
  and frequent-product access. Verify workspace/account isolation and persistence.
- [x] List/history management: search, sorting, favourites, archive/unarchive, and
  copying a completed trip into a new planned list without changing history.
- [x] Durable data: structured local storage with migration/recovery, export and
  reviewed import/restore, and separate cloud records that can grow without
  rewriting one limited workspace blob. Verify failure/rollback, existing data,
  account separation, offline edits, and concurrent writes.
- [ ] Household sharing: email invitations, viewer/editor roles, editor-only item
  changes, membership management, conflict handling, and owner deletion that
  removes shared lists after an explicit warning. Currency remains GBP. These
  defaults were approved by the user. Verify server-side authorisation, revoked
  membership, invitation acceptance, offline/reconnect, and two-user behaviour.
- [ ] Release preparation: production email configuration, release signing,
  privacy/store materials, and a documented physical-device acceptance pass.
  Real device tests, signing credentials, provider/domain access, and store
  account details must be verified before claiming release readiness.

Receipt OCR, live retailer prices, comparisons, payments, and checkout are later
integrations, not promises of this implementation.

## Current milestone

Structured local storage, reviewed export/restore, previous-device-save recovery,
and separate private cloud records are implemented. Household sharing's backend
permission/invitation foundation, typed Flutter repository and isolated device
caches, an offline sync controller and account lifecycle integration are verified;
its app/offline flows and mail
delivery remain, followed by release preparation. The full goal remains active.

## Evidence

- `7ee8b98`: immutable planned quantities/estimates, strict validation, legacy
  record migration, and the full implementation checklist.
- `f8756e8`: Plan/Shop modes, independent totals, price confirmation, picker
  controls, saved mode/progress, scanner merge preservation, and full original
  plans in History. All 224 tests pass; Flutter analysis is clean. Actual-widget
  phone previews are in `docs/previews/planning-*.png`; the renderer uses only
  synthetic in-memory records. Production device acceptance remains outstanding.
- `f1caee7`: grocery category suggestions with manual overrides, persisted
  categories across list/history/import flows, independent category filters,
  grouped Basket sections, and category browsing for recommendations. All 230
  tests pass; analysis is clean. Category and recommendation phone renders were
  regenerated and reviewed, including the original next-card peek.
- `bdb3186`: private product favourites, hidden and less frequent suggestions,
  reversible controls with protection against overwriting newer choices, and
  Your products with searchable/category-filtered favourites and recurring picks.
  Guest import explicitly includes choices and retains account choices on clashes.
  All 240 tests pass; analysis is clean. Widget renders for Home, favourites,
  regulars, hidden choices, and menus were reviewed.
- `347bfcc`: searchable/sortable Lists and History, record favourites, reversible
  archives, saved-list renaming/last-used tracking, and reviewed trip-to-plan
  copying with save-before-switch protection. History contents and timestamps
  remain immutable. All 248 tests pass; analysis and iOS Simulator/Android Debug
  builds pass. Actual library/archive/history/reuse screens were rendered and
  reviewed, including the larger-text archive flow.

## Remaining external inputs and compatibility work

- Household account lifecycle: production startup now creates account-bound
  sharing workspaces. All 320 tests pass and analysis is clean. Seven new session tests cover controller ownership,
  sign-out/switch isolation, rapid re-entry during a save, deletion barriers,
  and delayed account actions. Open household controllers refresh on app resume.
  Household screens and real-device acceptance remain required.

- Household offline controller: all 313 tests pass and analysis is clean.
  Fourteen new tests verify reconnect, two-shopper conflicts, reviewed choices,
  pending edits during uploads, role downgrade/revocation, failed device writes,
  stale reviews, automatic sync and shutdown barriers. Account lifecycle wiring,
  household screens, conflict-review UI and real-device acceptance remain open.

- Household client foundation: typed models/repository and isolated SQLite
  caches are implemented. All 299 tests pass and analysis is clean. Adapter tests
  verify paging, revision/role changes, invitation scoping and late account-switch
  responses. Real SQLite tests verify reopen, pending/base/recovery separation,
  rollback and account-wide cache erasure. The UI, reconnect controller and
  controller shutdown before account erasure remain required.

- Household backend: migrations `20261028065421` and `20261028065707` are applied.
  Rollback-only live tests verify owner/editor/viewer roles, actual verified-email
  invitation binding, viewer write denial, immediate downgrade/revocation, CAS,
  leaving, owner-deletion cascades, and cross-household isolation. The account
  deletion warning and cancellation pass their UI regression. App/offline sharing
  and notification delivery are still open; see [sharing details](HOUSEHOLD_SHARING.md).

- Private cloud records: migration `20261028063541` is applied. All 280 app tests
  pass and analysis is clean. Live rollback-only SQL checks cover ownership,
  migration, old-writer gating, CAS, invalid-patch rollback, deletion, all nested
  record kinds, and growth to 10,000 records beyond the former blob limit.
  New records use paging and delta writes; conflict review remains whole-workspace
  and full client hydration remains a documented bound. See [cloud records](CLOUD_RECORDS.md).

- Local SQLite and portable backups: all 275 tests pass; analysis is clean.
  Real SQLite transactions test migration races, rollback, separate scopes,
  malformed/future records, bounded row changes, and recovery. Restore tests
  cover local/cloud edits arriving during review or a pending write. See
  [data and backups](DATA_AND_BACKUPS.md) for the user flow and remaining limits.
  iOS Simulator Debug and Android Debug builds pass with the new plugins.
  Actual widget renders were reviewed, including larger text. Physical-device
  file selection and restoration still need acceptance testing.

- The user approved email invitations, viewer/editor roles, editor-only changes,
  deletion of owned shared lists on owner account deletion after a warning, and
  GBP for this phase.
- A question about an existing email provider/verified sender domain is pending.
  Never request passwords or private API keys in chat. Public mail delivery needs
  provider/domain configuration and an actual delivery check.
- Portable shopping snapshots remain version 3. Cloud protocol 2 separately gates
  older writers after an account's transactional migration; nested new fields are
  preserved. The original cloud snapshot remains a migration fallback.
- Supabase project `igytgwdxljbnxfjtufui` was rechecked: ACTIVE_HEALTHY, Postgres
  17.11, five migrations. Current changelog/docs were consulted. New tables have
  explicit grants and RLS. Advisor results are documented per milestone;
  household invitation indexes have expected unused-index information initially.
- Physical-device acceptance, production signing, and store/provider ownership
  still require real external verification. Build success is not release approval.
