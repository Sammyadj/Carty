# Cloud development phases

## Phase one: private accounts and recovery

Implemented: City as the selected interface, optional email-link sign-in, an editable display name, private cloud saving, separate guest/account caches, explicit guest-data copying, offline editing, revision conflicts and a recovery copy, completed shopping history, and account deletion. GBP and shopper-entered shelf prices remain the current behavior.

Finishing a shop records the products marked as picked and their entered prices. It does not charge anyone, verify a receipt, or place an order. This preserves a useful history without inventing a retailer checkout integration.

The first backend stores one private workspace per account. Before larger histories or collaboration, migrate to individual list, item, trip, and membership records with stable IDs, per-record revision checks, pagination, resumable migrations, and export. Preserve current local data through that change. Cloud saving still needs a local cache, so it is not a way to remove all shopping data from the device.

## Phase two: release readiness and richer planning

Validate email delivery and two-device behavior, configure production SMTP, complete store/privacy work, and replace Android debug signing. Add export/restore and practical history/list management after testing typical data volumes. Decide whether a completed trip can seed a new basket, keeping the historical record immutable. Planned versus paid totals should be explicit before spending reports are added.

## Phase three: shared shopping lists

The user approved email invitations with viewer/editor roles, editor-only item
changes (including checking products off), deletion of owned shared lists on
account deletion after an explicit warning, and GBP for this phase. Prices
continue to be entered per item. Receipt interpretation and currency expansion
remain later decisions.

Sharing still needs revocable invitations, owner/editor/viewer roles, membership RLS, conflict behavior, offline changes, the approved deletion rules, and clear attribution. Private workspaces currently expose no share links or memberships. Do not retrofit sharing by weakening the private workspace policies. Local structured storage and portable backups are implemented; see [the active checklist](IMPLEMENTATION_PROGRESS.md) for remaining cloud and sharing work.

## Phase four: retailer integrations and optional checkout

A product barcode identifies an item; it does not authorize payment or supply every shop's current price. Shop-approved prices require a merchant catalog, store identity, freshness, and retailer agreements. Checkout would additionally require a real merchant/order/payment flow, reconciliation, refunds, and customer support. Keep it a separate product decision after the shopping companion and sharing flows have proved useful.
