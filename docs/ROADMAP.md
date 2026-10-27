# Carty roadmap

Carty's aim is to make a shopping trip easier to plan and keep within budget. It should remain quick to use in a shop and clear enough that the user understands every change to their basket.

The three root-level mockups are the visual direction, not a list of completed integrations. See the [mockup gap analysis](MOCKUP_GAP_ANALYSIS.md) for the feature-by-feature comparison and what remains.

## Stage 1: dependable shopping and reusable lists

The current implementation establishes:

- One reactive cart state shared by all screens.
- Immutable item records with stable IDs and integer-pence calculations.
- Validated add/edit forms and quantities that can be zero for products not yet picked up.
- A green Carty theme and home dashboard with budget progress, near-budget and over-budget feedback, running cost, and simple shopping tips.
- A bottom bar that keeps the total, remaining budget, and Add item control visible on home and full-cart screens.
- Home, Lists, and Tips navigation with functional destinations for current local data.
- Basket icon avatars that make rows easier to recognize; these are visual hints, not catalog photos or product categories.
- Local saving of the current basket, budget, and reusable lists.
- A saved-list library and screen-based reuse flow: choose a mode, review the items and last-entered prices, then apply. The review explains that this replaces the active basket.
- Reuse that either duplicates quantities and budget, or sets quantities to zero and removes the budget while retaining products and last-entered prices.
- Preserved saved originals, plus tests and automated quality checks.

The separate Tips view uses only information already entered in Carty. Its local rules describe the situation and offer a useful next step, without claiming to know store prices or taking actions on the user's behalf. This stage does not calculate cheaper alternatives, health recommendations, or spending forecasts.

The mockups use different navigation sets. Home, Lists, and Tips are the current choice because those destinations work with existing data. Search, Products, History, Settings, and Profile should be added with complete flows. Saved lists record when they were saved; last-used tracking is not implemented. Reusing a list creates the next active basket, not a retained historical shopping session.

## Stage 2: planning and shopping history

Add multiple named shopping sessions, favourites, saved-list search, a dedicated template editor, and a clear action to finish a trip. Keep completed trips separate from reusable templates, and allow a previous trip to become a new basket without changing the historical record.

Track planned and actual prices explicitly before introducing price history or spending summaries. Add export and restore, and move shopping records to a database with migrations and appropriate recovery behavior as the data grows. The current preferences snapshot is a small-MVP storage choice.

## Stage 3: product capture and useful comparisons

The first product-capture milestone is implemented: camera or manual barcode entry, checksum validation, Open Food Facts lookup, editable name review, manual shelf-price confirmation, and duplicate-product merging. Product identifiers, brand, and display pack size persist in baskets and saved lists. A bounded local cache supports previously matched products offline; unknown or unavailable matches allow manual details. The review attributes the catalog and explains that prices come from the shopper. Physical-device scanner checks and native iOS verification remain release work.

Catalog search, normalized pack sizes/units, categories, and licensed product images remain future work. Product icon avatars do not supply these. A barcode does not provide a universal current price: automated price lookup needs a reliable retailer or product-price source, and users must be able to enter or correct a price manually.

Introduce normalized pack sizes and units before unit-price comparisons such as pounds per kilogram or litre. Price refresh on list reuse and “was/current” highlights require store-specific source and timestamp data; until then reuse retains last-entered prices. Receipt capture can later help record actual purchases, with a review step for uncertain text and amounts. Any price comparison should show its source, store, and freshness rather than implying a live offer.

## Stage 4: optional assistance and sharing

AI can suggest substitutions, remind someone about products they often buy, or explain spending patterns once Carty has suitable data. Make it optional, explain what data leaves the device, and let the user accept each suggestion. Do not automatically add products, change quantities, or make purchases.

The mockup's cheaper-alternative, healthy-choice, and spending-forecast cards need separate foundations: comparable product/price data, suitable nutrition data and a defined scope, and enough completed-trip history to validate predictions. Do not fill these cards with invented savings or forecasts.

Household sharing and cloud backup need explicit account and backend decisions, offline synchronization, conflict handling, and deletion/export controls. Build them after the local shopping flow has proved useful.

## Release work

Before public distribution:

- Replace Android debug signing with the owner's production signing setup and verify iOS provisioning.
- Confirm app identifiers, branding, icons, screenshots, and store metadata.
- Test restart/restore, keyboard behavior, small screens, large text, screen readers, and long lists on real Android and iOS devices.
- Document the data actually collected and transmitted by the final app and its plugins.
- Upgrade Flutter and dependencies as a separate change with analysis, tests, and native build verification.

These stages are a development order, not a promise of retailer integrations, free product-price data, or AI accuracy. Each addition should earn its place by making an everyday shopping task easier.
