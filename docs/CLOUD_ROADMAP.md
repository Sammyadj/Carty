# Cloud development phases

## Phase one: private accounts and recovery

Implemented: City as the selected interface, optional email-link sign-in, an editable display name, private cloud saving, separate guest/account caches, explicit guest-data copying, offline editing, revision conflicts and a recovery copy, completed shopping history, and account deletion. GBP and shopper-entered shelf prices remain the current behavior.

Finishing a shop records the products marked as picked and their entered prices. It does not charge anyone, verify a receipt, or place an order. This preserves a useful history without inventing a retailer checkout integration.

The first backend stores one private workspace per account. Before larger histories or collaboration, migrate to individual list, item, trip, and membership records with stable IDs, per-record revision checks, pagination, resumable migrations, and export. Preserve current local data through that change. Cloud saving still needs a local cache, so it is not a way to remove all shopping data from the device.

## Phase two: release readiness and richer planning

Validate email delivery and two-device behavior, configure production SMTP, complete store/privacy work, and replace Android debug signing. Add export/restore and practical history/list management after testing typical data volumes. Decide whether a completed trip can seed a new basket, keeping the historical record immutable. Planned versus paid totals should be explicit before spending reports are added.

## Phase three: shared shopping lists

Design the invitation and permission model before implementing it. The following user questions remain open:

- Invitations by email, shareable link, or both?
- Can viewers check off products, or is that an editor action?
- Are prices entered per item at the shop, derived from a reviewed receipt, or both?
- If an owner deletes their account, should a shared list transfer, be archived, or be deleted?
- Continue with GBP, or introduce explicit currency per list/trip?

Sharing will need revocable invitations, owner/editor/viewer roles, membership RLS, item-level conflict behavior, offline changes, ownership transfer/deletion rules, and clear attribution. Private workspaces currently expose no share links or memberships. Do not retrofit sharing by weakening the private workspace policies.

## Phase four: retailer integrations and optional checkout

A product barcode identifies an item; it does not authorize payment or supply every shop's current price. Shop-approved prices require a merchant catalog, store identity, freshness, and retailer agreements. Checkout would additionally require a real merchant/order/payment flow, reconciliation, refunds, and customer support. Keep it a separate product decision after the shopping companion and sharing flows have proved useful.
