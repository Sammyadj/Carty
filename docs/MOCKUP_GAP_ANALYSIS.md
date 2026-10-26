# Mockup gap analysis

The three reference images describe a broader product than the current local Flutter MVP:

- [Grocery budget dashboard](../Carty%20Grocery%20Budget%20App%20Mockup.png)
- [Saved-list reuse flow](../Carty%20Shopping%20List%20Reuse%20Flow.png)
- [Smart shopping and scanning](../Carty%20Smart%20Shopping%20App%20Mockup.png)

The UI polish pass brings the manual shopping flow closer to that direction. The table distinguishes that work from features that still need data, integrations, or a larger product flow. It is a feature audit, not a native build or device-test result.

| Mockup feature | Current implementation, including this polish pass | Remaining work and requirements |
| --- | --- | --- |
| Green Carty branding and card-based home | Green theme, budget dashboard, clearer basket rows, and product icon avatars. | Finish app icons and store assets; check layout, contrast, and large text on physical devices. Icon avatars are visual hints derived from names, not product photos or catalog classifications. |
| Budget amount, edit, spent, remaining, progress | Implemented from the active basket using integer pence; includes near-budget and over-budget feedback. | No forecasting is implied by the progress bar. Broader currency support would need explicit money and formatting changes. |
| Add, edit, remove, and adjust basket products | Implemented with validated manual forms, quantity controls, and running totals. Quantity zero keeps a product pending. | The mockup's inline name/price fields use a different layout; the app uses an item form. Barcode and catalog entry remain separate future work. |
| Bottom navigation | Home, Lists, and Tips provide destinations backed by current local data. | The images show several different tab sets. Search/Products, History, Profile, and Settings are not implemented destinations; add them when their flows exist. |
| Saved shopping-list library | Named snapshots of the current basket can be saved, viewed, reused, and deleted. | A separate empty-list/template editor, favourites, and list search remain future work. The stored date is the save date, not a tracked last-used date. |
| Choose how to reuse, then review | Dedicated screens select duplicate or start-fresh mode, review products/prices, and apply the choice. The review warns that applying replaces the active basket. | There is one active basket. A new basket does not retain the previous basket as a completed shopping session or history record. |
| Duplicate or start fresh without changing the saved original | Duplicate keeps saved quantities and budget. Start fresh retains products and last-entered prices, sets every quantity to zero, and removes the budget. Both create independent active items. | Price changes made in the active basket do not update the saved snapshot. Editing a saved template would need an explicit flow. |
| Current prices and changed-price highlights during reuse | Review shows the saved, last-entered prices for checking before shopping. | Automatic refresh and “was/current” comparisons need a reliable price source, store identity, timestamps, and no-result/offline handling. No live price claim is made. |
| Smart tip card and separate Tips view | Local rules use basket totals, budget, and pending quantities to provide explanatory tips. | These are not AI recommendations. Basket-specific cheaper alternatives, health guidance, and spending forecasts are not implemented. |
| Scan a barcode, show a matched product, add it | Not implemented. Manual entry remains available. | Needs camera permissions, scanning, product lookup, match review, correction, and offline/no-match flows. A barcode identifies a product; it does not encode a universal current shelf price. |
| Search catalog; show pack sizes, categories, and product photos | Basket-only name search and a pending-products filter are available. Catalog search and catalog metadata are not implemented; item data currently holds name, unit price, and quantity. | Choose a catalog/data source and image rights; add identifiers, pack size and units, category fields, catalog search, and migrations before using them for comparisons. |
| Cheaper alternatives and unit-price savings | Generic advice to compare shelf labels is available. No automatic comparison is performed. | Needs comparable products, normalized sizes/units, reliable retailer prices, and source/freshness information. Users must review any proposed substitution. |
| Healthy-choice and spending-forecast cards | Not implemented. | Health suggestions require suitable product/nutrition data and defined scope. Forecasting requires meaningful shopping history and a validated method; a static card must not imply a calculated prediction. |
| History, accounts, profile, cloud, and sharing | Not implemented. The active basket, budget, and saved lists persist locally. | Add a completed-trip model and database/recovery plan for history; accounts, backend, sync conflicts, export/deletion, and privacy decisions for cloud or sharing. |

Remaining feature work includes product data and capture, completed shopping trips, and history. The [roadmap](ROADMAP.md) sets out the dependencies. Existing Android/iOS toolchain constraints and release requirements remain documented in the [README](../README.md).
