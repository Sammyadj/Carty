# Mockup gap analysis

The three reference images describe a broader product than the current local Flutter MVP:

- [Grocery budget dashboard](../Carty%20Grocery%20Budget%20App%20Mockup.png)
- [Saved-list reuse flow](../Carty%20Shopping%20List%20Reuse%20Flow.png)
- [Smart shopping and scanning](../Carty%20Smart%20Shopping%20App%20Mockup.png)

The UI polish pass brings the manual shopping flow closer to that direction. The table distinguishes that work from features that still need data, integrations, or a larger product flow. It is a feature audit, not a native build or device-test result.

| Mockup feature | Current implementation, including this polish pass | Remaining work and requirements |
| --- | --- | --- |
| Carty branding and card-based home | Selected City theme, budget dashboard, clearer basket rows, product icon avatars, and custom launcher icons. | Finish store assets; check layout, contrast, and large text on physical devices. Icon avatars are visual hints derived from names, not product photos or catalog classifications. |
| Budget amount, edit, spent, remaining, progress | Implemented from the active basket using integer pence; includes near-budget and over-budget feedback. | No forecasting is implied by the progress bar. Broader currency support would need explicit money and formatting changes. |
| Add, edit, remove, and adjust basket products | Implemented with validated manual forms, barcode-assisted entry, quantity controls, and running totals. Quantity zero keeps a product pending. | The mockup's inline name/price fields use a different layout; the app uses an item form. |
| Bottom navigation | Home, Lists, Tips, and History; account/profile/sync opens from Home. | Catalog Search/Products and general Settings remain future work. |
| Saved shopping-list library | Named lists can be saved, continued with automatic updates, reused, and deleted. The currently edited list is labelled and restored after restart. | Favourites and list search remain future work. The stored date is the latest save date, not a tracked last-used date. |
| Choose how to open, then review | Continue editing retains the same list, quantities, prices, and budget. Duplicate and start-fresh modes create separate baskets. Unsaved changes are protected before switching. Finish shopping explicitly creates a historical record. | There is one active basket. Starting a new basket does not automatically claim the previous one was purchased. |
| Duplicate or start fresh without changing the saved original | Duplicate keeps saved quantities and budget. Start fresh retains products and last-entered prices, sets every quantity to zero, and removes the budget. Both create independent active items. | Continue editing intentionally updates the saved original. Save a copy keeps a separate named version. |
| Current prices and changed-price highlights during reuse | Review shows the saved, last-entered prices for checking before shopping. | Automatic refresh and “was/current” comparisons need a reliable price source, store identity, timestamps, and no-result/offline handling. No live price claim is made. |
| Smart tip card and separate Tips view | Local rules use basket totals, budget, and pending quantities to provide explanatory tips. | These are not AI recommendations. Basket-specific cheaper alternatives, health guidance, and spending forecasts are not implemented. |
| Scan a barcode, show a matched product, add it | Implemented with camera/manual capture, Open Food Facts lookup, editable match review, explicit shelf price and quantity, repeat-product merging, and cached/offline/no-match fallback. Product metadata persists with saved lists. | Check camera and permissions on physical devices. A barcode identifies a product; live retailer price lookup remains separate work. UPC-E and QR capture are outside this version. |
| Search catalog; show pack sizes, categories, and product photos | Basket-only name search and a pending-products filter are available. Scanned items retain barcode, brand, and display pack size. Product icon avatars remain decorative. | Catalog search, normalized pack sizes and units, category fields, and appropriately licensed photographs remain future work. |
| Cheaper alternatives and unit-price savings | Generic advice to compare shelf labels is available. No automatic comparison is performed. | Needs comparable products, normalized sizes/units, reliable retailer prices, and source/freshness information. Users must review any proposed substitution. |
| Healthy-choice and spending-forecast cards | Not implemented. | Health suggestions require suitable product/nutrition data and defined scope. Forecasting requires meaningful shopping history and a validated method; a static card must not imply a calculated prediction. |
| History, accounts, profile, cloud, and sharing | Completed-trip history, optional email-link accounts, display name, private Supabase workspaces, offline caches, revision conflict recovery, guest import, and account deletion. | Production email delivery, physical two-device checks, export, and larger-scale storage remain. Sharing roles, invitations, currencies, and ownership decisions are deferred. |

Remaining feature work includes broader catalog data, sharing, larger histories, export, and retailer integrations. The [cloud roadmap](CLOUD_ROADMAP.md) records the next phases and unanswered questions. Native verification and release requirements remain documented in the [README](../README.md).
