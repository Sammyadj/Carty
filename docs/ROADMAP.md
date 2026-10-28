# Carty roadmap

Carty's aim is to make a shopping trip easier to plan and keep within budget. It should remain quick to use in a shop and clear enough that the user understands every change to their basket.

City is the selected interface. The root-level mockups remain product references, not a list of completed integrations. See the [mockup gap analysis](MOCKUP_GAP_ANALYSIS.md) and the newer [cloud phases and open decisions](CLOUD_ROADMAP.md).

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
- Continue editing a named list with automatic updates to products, quantities, prices, and budget, retaining the active list across app restarts.
- Reuse that either duplicates quantities and budget, or sets quantities to zero and removes the budget while retaining products and last-entered prices. These modes preserve the saved original.
- Save-before-switch protection, autosave recovery, tests, and automated quality checks.

The separate Tips view uses only information already entered in Carty. Its local rules describe the situation and offer a useful next step, without claiming to know store prices or taking actions on the user's behalf. This stage does not calculate cheaper alternatives, health recommendations, or spending forecasts.

Navigation now includes Home, Lists, Tips, and History; the Home account action opens sign-in, profile, and sync controls. Catalog Search/Products and a general Settings destination remain future work. Saved lists record their save date; last-used tracking is not implemented. Reusing a list creates an active basket; Finish shopping explicitly records a completed trip.

## Stage 2: planning and shopping history

Named editable lists and Finish shopping are available. History keeps completed picked products separate from reusable lists. Favourites, saved-list search, and reusing a previous trip as a new basket remain future work.

Track planned and actual prices explicitly before introducing price history or spending summaries. Add export and restore, and move shopping records to a database with migrations and appropriate recovery behavior as the data grows. The current preferences snapshot is a small-MVP storage choice.

## Stage 3: product capture and useful comparisons

Product capture includes camera or manual barcode entry, checksum validation, Open Food Facts lookup with UPCitemdb general-retail fallback, editable name review, manual shelf-price confirmation, and duplicate-product merging. Product identifiers, sources, brand, and display pack size persist in baskets and saved lists. A bounded local cache supports matched products and manually confirmed names offline; unknown or unavailable matches allow manual details. The review attributes each source and explains that prices come from the shopper. UPCitemdb's free-tier quota limits evaluation capacity; assess real-shop coverage before selecting a production plan. Physical-device scanner checks remain release work.

Catalog search, normalized pack sizes/units, categories, and licensed product images remain future work. Product icon avatars do not supply these. A barcode does not provide a universal current price: automated price lookup needs a reliable retailer or product-price source, and users must be able to enter or correct a price manually.

Introduce normalized pack sizes and units before unit-price comparisons such as pounds per kilogram or litre. Price refresh on list reuse and “was/current” highlights require store-specific source and timestamp data; until then reuse retains last-entered prices. Receipt capture can later help record actual purchases, with a review step for uncertain text and amounts. Any price comparison should show its source, store, and freshness rather than implying a live offer.

## Stage 4: optional assistance and sharing

Home now has an offline recommendation engine using the current basket, saved lists, and completed shops. It explains recurring picks and products picked together, separates generic starting ideas from personal evidence, filters known estimates against remaining budget, and requires review before adding. This is personal ranking from recorded shopping activity; shared popularity, retailer catalogs, and AI-generated substitutions remain future work.

AI can suggest substitutions, remind someone about products they often buy, or explain spending patterns once Carty has suitable data. Make it optional, explain what data leaves the device, and let the user accept each suggestion. Do not automatically add products, change quantities, or make purchases.

The mockup's cheaper-alternative, healthy-choice, and spending-forecast cards need separate foundations: comparable product/price data, suitable nutrition data and a defined scope, and enough completed-trip history to validate predictions. Do not fill these cards with invented savings or forecasts.

Private accounts and Supabase cloud saving now include guest separation, offline synchronization, revision conflict handling, profile editing, and account deletion. See [setup](CLOUD_SETUP.md). Household sharing, export, and larger-scale record storage remain separate work; [the cloud roadmap](CLOUD_ROADMAP.md) retains the unanswered sharing and currency decisions.

## Release work

Before public distribution:

- Replace Android debug signing with the owner's production signing setup and verify iOS provisioning.
- Confirm app identifiers, branding, icons, screenshots, and store metadata.
- Test restart/restore, keyboard behavior, small screens, large text, screen readers, and long lists on real Android and iOS devices.
- Document the data actually collected and transmitted by the final app and its plugins.
- Upgrade Flutter and dependencies as a separate change with analysis, tests, and native build verification.

These stages are a development order, not a promise of retailer integrations, free product-price data, or AI accuracy. Each addition should earn its place by making an everyday shopping task easier.
