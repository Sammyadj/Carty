# Carty everyday shopping improvements

This tracks the full implementation requested on 28 October 2026. Each working
milestone includes regression checks and a local commit. Publishing remains a
separate action when authorised.

## Requirements and verification

- [ ] Planning and shopping: separate planned quantities/estimated prices from
  picked quantities/confirmed shelf prices; show estimated and picked totals,
  budget remaining, and complete only picked items. Verify migration, restart,
  saved-list continuation, scan merging, and immutable history.
- [ ] Grocery categories: editable product classification, category filtering,
  grouped shopping lists, and horizontal product browsing. Verify manual
  overrides, uncategorised products, search combinations, and larger text.
- [ ] Personal recommendations: favourites, hide suggestions, suggest less often,
  and frequent-product access. Verify workspace/account isolation and persistence.
- [ ] List/history management: search, sorting, favourites, archive/unarchive, and
  copying a completed trip into a new planned list without changing history.
- [ ] Durable data: structured local storage with migration/recovery, export and
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

Inspecting the existing models, storage, cloud contract, and UI before extending
planning and shopping. Baseline: clean working tree, 213 passing tests, City UI.

## Evidence

Record each milestone's commit, checks, and remaining external requirements here.
