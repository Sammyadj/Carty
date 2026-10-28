# Household sharing implementation

## Current status

The backend permission/invitation foundation, typed Flutter repository and
account-scoped SQLite cache, offline sync controller and account lifecycle
integration are implemented and verified. The app's household library, editing screens, conflict-review UI,
and recipient notification delivery remain to be implemented. Household sharing
is **not yet available as a completed app feature**. The account-delete dialog
now explicitly warns that owned shared lists disappear for everyone.

Approved defaults: invitations addressed by email; viewer/editor roles; only
owners/editors change products; deleting an owner removes owned shared lists
after a warning; GBP for this phase. Private account workspaces remain separate.

## Database and API

Applied migrations:

- `20261028065421_household_sharing.sql`
- `20261028065707_index_household_invitation_members.sql`

`carty_shared_lists` holds owner, name, budget, Plan/Shop mode, GBP, and revision.
`carty_shared_items` holds individual validated products, order, and last-change
revision. `carty_shared_members` grants viewer/editor access. Owners are implicit
and cannot be reassigned through a membership change. Invitations contain the
intended verified email, role, a frozen list/sender label, seven-day expiry,
acceptance/revocation state, and delivery status.

The authenticated RPC is `carty_shared_action(p_action, p_args)`. Its public
wrapper runs as invoker; guarded logic and RLS helpers live in the unexposed
`carty_private` schema with empty search paths. No direct client table writes
are granted. RLS restricts list/items to members/owners, rosters to owners or
the caller's own membership, and invitations to the owner or intended verified
recipient. Email comes from `auth.users`, not editable metadata or a JWT's email
claim. Revocation and role changes are checked in the database for every action.

| Action | Arguments and permission |
| --- | --- |
| `create` | `name`, nullable `budgetPence`, `isPlanning`, `items`; verified caller becomes owner |
| `save` | Same content plus `listId`, `expectedRevision`; owner/editor only; stale revision returns `conflict: true` |
| `invite` | `listId`, `email`, viewer/editor `role`; owner only; creates an in-app invitation |
| `accept` / `decline` | `invitationId`; verified recipient only, active/unexpired invitation |
| `revoke` | `invitationId`; owner only |
| `member` | `listId`, `userId`, nullable `role`; owner changes role or removes membership |
| `leave` | `listId`; non-owner removes their own membership |
| `delete` | `listId`, `expectedRevision`; owner only; stale revision requires review |

All shared-list mutations serialise per list. List locks precede invitation-row
locks to avoid an accept/revoke lock-order inversion. A save updates only changed
item rows, retains unchanged row revisions, and removes omitted products in the
same transaction as its revision change. A shared list is limited to 1,000 items;
its network save currently sends that list's item array. Conflicts will require
an explicit reviewed choice rather than silently adding quantities together.

Deleting an account cascades its owned shared lists, items, memberships, and
invitations. Its membership in someone else's list is removed without deleting
the other owner's list. Server deletion cannot erase another device's offline
copy or exported files; the client implementation must make that boundary clear.

## Invitation delivery

Creating an invitation currently returns `deliveryStatus: in_app`. It does not
send an email or claim one was sent. The intended recipient can be authorised
only after signing in with that verified email. Production notification email
requires the pending sender/provider decision, secure server-side credentials,
delivery tracking, abuse controls, and a genuine delivery check. Never put a
mail-provider secret in Flutter or ask for it in chat.

## Verified foundation

`supabase/tests/household_sharing_security.sql` passed against Carty with synthetic
fixtures inside a rolled-back transaction. It verifies:

- owner creation, valid barcode/item validation, and no false delivery claim;
- outsider isolation despite spoofed email/role claims and user metadata;
- invitation visibility and acceptance bound to the actual verified email;
- editor item changes, denied membership management, and stale revision checks;
- viewer read access and denied changes;
- immediate role downgrade/revocation with the same caller token;
- leaving, invitation revocation, and deleted-owner token rejection;
- owner deletion cascades while another household remains; anonymous API denial.

The account UI regression verifies the shared-deletion warning and cancellation.
All eight account-flow tests pass; the preceding full suite passed 280 tests.
Security advisors retain only the two documented legacy definer-function warnings.
The missing accepted-user FK index was added. New invitation indexes may show
[unused-index information](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)
before normal traffic; retain them for recipient lookup and account deletion.

## Required next work

Add the household library, owner invite and
member controls, recipient accept/decline flow, read-only viewer UI, and shared
shopping controls that preserve estimates and picked quantities. Add adapter,
offline/reconnect, two-user, and large-text regression checks. Verify real devices
and notification delivery before marking the full sharing requirement complete.

## Flutter repository verification

`lib/sharing` provides immutable shared content, roles, invitations, members,
and an account-bound Supabase adapter. Shared content contains only the selected
basket, budget and Plan/Shop mode, preserving estimates and picked quantities.
Private saved lists, history and recommendations are not included.

Downloads page 500 products at a time, check exact row counts and ordering, and
recheck both revision and membership before publishing. Role changes need this
separate check because they do not advance the content revision. Revocation
returns unavailable; conflicting content changes retry a bounded three times.
Saves use the server's expected-revision check and acknowledge exactly the sent
content rather than fetching and accidentally acknowledging a later edit.

The 12 tests in `test/shared_repository_test.dart` exercise the real Supabase
Dart request/response adapter with synthetic HTTP responses: 1,000 products,
concurrent edits, unchanged-revision downgrades, revocation during download,
partial/foreign/malformed responses, invitation scoping, expiry display,
permission denial, account switches, and truthful in-app delivery status.
Server authorisation remains covered separately by the live rollback SQL tests.
These adapter checks do not prove offline UI or two-device acceptance; those
remain required above. Library refreshes currently hydrate each accessible
header separately; optimise that if household counts justify batching.

## Device cache verification

`SqliteSharedListCache` stores each account/list pair in a separate structured
database scope. It retains the accepted server base, pending local content,
an explicit recovery copy and last-known header/role. Private lists/history and
preferences are rejected. A remembered role is not current permission: the
controller must recheck membership on reconnect and respect persisted access
loss. No offline screen is wired yet.

Six real SQLite tests in `test/shared_list_cache_test.dart` cover database
reopening, pending estimates/quantities, account/list isolation, malformed
metadata, transactional rollback, single-list removal, and account-wide erasure.
Removing an account cache now transactionally clears its private and household
records, bases, recovery copies and metadata while retaining guest/other-account
data. Tombstones prevent legacy private data from being imported again.

Account deletion stops household callbacks and awaits pending device writes
before erasing those scopes. Database isolation alone cannot stop a live
controller from issuing a later write; preserve the session shutdown barrier.

## Offline controller verification

`SharedListController` serialises device saves separately from network requests.
It publishes a local edit only after its device save succeeds. Reconnect compares
the accepted server base before submitting, uses the server revision guard, and
keeps edits made during an upload pending against that exact submission. Failed
downloads never replace the local copy; corrupt cache data is preserved for
explicit recovery. Automatic sync is debounced after local edits.

Conflicts retain both copies. The UI must present the returned `SharedConflict`
for review and pass that same review to `keepLocal` or `useRemote`. New local
edits invalidate old forms/reviews. Keeping local checks the current server
revision again; choosing remote retains the discarded local content as recovery.
No quantities are silently combined. Downgraded viewers cannot submit pending
edits, and revoked access persists across restart while retaining unsynced work.

Fourteen controller tests cover offline restart/reconnect, two independent
shoppers, competing writes, both conflict choices, edits during upload, stale
forms/reviews, role downgrade, revocation, post-fetch permission denial, device
write failure, corrupt caches, automatic sync, and late callbacks after account
switch/disposal. They use synthetic repositories and caches; server checks and
real SQLite are tested separately. Physical-device acceptance is still required.

`dispose()` stops callbacks and future queued edits. AppSession owns a
`SharedWorkspace` for each login lifetime and awaits `writesSettled` before
account erasure or creating a replacement lifetime. Shared screens are not yet
accessible; keep the sharing requirement open until the user flows are wired
and verified together.

## Account lifecycle verification

Production startup now supplies an account-bound sharing repository. Each login
owns one controller per opened household list; reopening a screen should reuse
that controller rather than disposing it from the screen. App resume refreshes
opened household lists. Sign-out/account changes close the old lifetime while
retaining its offline cache. A quick return to the same account waits for old
writes, then creates fresh controllers which read the preserved cache.

Seven session regressions verify sign-out, isolated account caches, late network
callbacks, rapid return during a device write, deletion waiting for shared saves,
failed remote deletion preserving access, and late sign-out/deletion actions not
affecting a different account. The tests use synthetic account/repository/cache
adapters; physical two-account device acceptance remains outstanding.
