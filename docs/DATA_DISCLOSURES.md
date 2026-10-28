# Data disclosures and store-review inventory

Settings → **Your data** explains the current app's data flows and links to
existing backup/account controls. It works offline and does not send requests
or modify shopping data merely by opening the page.

This is an implementation inventory for the owner to review when preparing a
published privacy policy and store declarations. It is not a published policy
or a completed App Store/Google Play privacy submission. The operator's public
contact, policy URL, processor retention and final distribution settings still
need confirmation.

| Data / action | Current handling | User control / limits |
| --- | --- | --- |
| Basket, budgets, named lists, history, preferences | App-private SQLite; separate guest/account scopes | Data & backups provides export/import/recovery; guest shopping needs no account |
| Product cache | Separate bounded preferences cache, up to 100 barcode/product matches, including confirmed names | Expendable lookup cache; not the source of saved shopping lists |
| Item suggestions and recommendations | Local shopping data and bundled names/rules | Favourite, hide and suggest-less controls; no AI service receives typed names |
| Email, account ID, profile display name | Supabase Auth and profile table | Optional sign-in; editable display name; account deletion |
| Signed-in shopping records | Private Supabase records, scoped by owner | Sync/conflict controls; guest import is explicit; unsynced changes remain device-only |
| Auth session | Supabase SDK-managed local session storage | Sign-out closes the session; do not describe SDK storage as a custom hardware-backed vault |
| Household products, prices, quantities, budget, progress | Shared Supabase records for authorised owner/editors/viewers | Only selected content is shared; private history/preferences are excluded; owners manage access |
| Invitation email and membership | Verified-email invitations and role records | Recipient accepts/declines in app; owner revokes/removes; no notification email is currently sent |
| Camera frames | Processed on device by the scanner | Camera requested through the scan flow; manual barcode entry/details are available |
| Barcode lookups | Barcode and normal HTTP metadata to Open Food Facts, with UPCitemdb fallback; app User-Agent identifies Carty/version | Cache can serve matches locally; providers do not receive basket, prices, budget or typed item names |
| Backup files | Readable JSON saved through the system picker | User chooses location; credentials excluded; files are not encrypted and are not removed by deleting an account |

Account deletion removes the private cloud workspace/profile and cascades owned
shared lists. The app drains pending household device writes before clearing
that account's local scopes. Guest data, other accounts and other owners' shared
lists remain. Device cleanup failures are reported explicitly. Remote offline
copies and exported files cannot be erased by the account-deletion API. Sign-out
retains local account data rather than acting as deletion.

## Owner decisions before public distribution

- Confirm the operator name and public privacy/support contact, then publish a
  policy at a stable URL and add that URL to the app/store materials.
- Review Supabase hosting/log/backups retention and access with the actual
  project plan; distinguish live-row deletion from provider backup retention.
- Choose an email provider and sender domain. Then document that processor,
  configure secrets on the server and verify actual sign-in/invitation delivery.
- Review Open Food Facts/UPCitemdb terms and real-shop coverage before scaling.
- Audit the final plugin/native privacy manifests and store data categories
  against this inventory. Do not mark a store checkbox from these notes alone.
- Complete physical camera, native file-picker, two-account/offline and account
  deletion acceptance. App-private storage is not a promise of encrypted backup
  files, device-loss recovery for unsynced edits or remote erasure of copies.

## Verification

The new UI tests open Your data through Settings, navigate to existing backup
and account screens, and verify that browsing leaves the shopping snapshot
unchanged. A narrow-phone test uses doubled text and reaches every section and
the backup action without layout exceptions. Backend deletion, isolation and
sharing checks remain documented in `CLOUD_SETUP.md` and `HOUSEHOLD_SHARING.md`.
