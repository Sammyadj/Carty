# Household sharing implementation

## Current status

The backend permission/invitation foundation and typed Flutter repository are
implemented and verified. The app's
household library, editing screens, local/offline cache, reconnect/conflict flow,
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

Build the role-aware shared-list controller, account-scoped
SQLite caches, reviewable offline conflicts, revoked-access handling, and safe
account-switch/deletion cleanup. Then add the household library, owner invite and
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
