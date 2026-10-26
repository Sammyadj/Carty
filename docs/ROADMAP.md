# Carty roadmap

Carty's aim is to make a shopping trip easier to plan and keep within budget. It should remain quick to use in a shop and clear enough that the user understands every change to their basket.

## Stage 1: dependable shopping and reusable lists

The current implementation establishes:

- One reactive cart state shared by all screens.
- Immutable item records with stable IDs and integer-pence calculations.
- Validated add/edit forms and quantities that can be zero for products not yet picked up.
- A home dashboard with budget status, running cost, and simple shopping tips.
- A bottom bar that keeps the total, remaining budget, and Add item control visible on home and full-cart screens.
- Local saving of the current basket, budget, and reusable lists.
- Saved-list actions that either duplicate quantities and budget or reset quantities and budget while retaining products and prices.
- Preserved saved originals, plus tests and automated quality checks.

The rule-based tips in this stage use only information already entered in Carty. They should describe the situation and offer a useful next step, without claiming to know store prices or taking actions on the user's behalf.

## Stage 2: planning and shopping history

Add multiple named shopping sessions, categories, favourites, search, and a clear action to finish a trip. Keep completed trips separate from reusable templates, and allow a previous trip to become a new basket without changing the historical record.

Track planned and actual prices explicitly before introducing price history or spending summaries. Add export and restore, and move shopping records to a database with migrations and appropriate recovery behavior as the data grows. The current preferences snapshot is a small-MVP storage choice.

## Stage 3: product capture and useful comparisons

Barcode scanning can reduce typing by identifying a product. A barcode does not provide a universal current price: price lookup needs a reliable retailer or product-price source, and users must be able to enter or correct a price manually. Plan camera permission, product lookup, no-match, offline, and incorrect-result flows before integrating a scanner.

Introduce pack sizes and units before unit-price comparisons such as pounds per kilogram or litre. Receipt capture can later help record actual purchases, with a review step for uncertain text and amounts. Any price comparison should show its source, store, and freshness rather than implying a live offer.

## Stage 4: optional assistance and sharing

AI can suggest substitutions, remind someone about products they often buy, or explain spending patterns once Carty has suitable data. Make it optional, explain what data leaves the device, and let the user accept each suggestion. Do not automatically add products, change quantities, or make purchases.

Household sharing and cloud backup need explicit account and backend decisions, offline synchronization, conflict handling, and deletion/export controls. Build them after the local shopping flow has proved useful.

## Release work

Before public distribution:

- Replace Android debug signing with the owner's production signing setup and verify iOS provisioning.
- Confirm app identifiers, branding, icons, screenshots, and store metadata.
- Test restart/restore, keyboard behavior, small screens, large text, screen readers, and long lists on real Android and iOS devices.
- Document the data actually collected and transmitted by the final app and its plugins.
- Upgrade Flutter and dependencies as a separate change with analysis, tests, and native build verification.

These stages are a development order, not a promise of retailer integrations, free product-price data, or AI accuracy. Each addition should earn its place by making an everyday shopping task easier.
