# Carty

Carty is a Flutter shopping companion for keeping track of the cost of a basket and staying within a budget. It is being developed in small, understandable stages: a dependable manual shopping flow first, then useful automation.

## Current MVP

- Add products with a name, unit price, and quantity; edit or remove them later.
- See a live basket total, remaining budget, and progress. Near-budget feedback starts at 80% of the budget; spending above the budget has an explicit over-budget status.
- Use a green Carty dashboard with product icon avatars and Home, Lists, and Tips navigation.
- Keep the total, budget status, and Add item control visible in a bottom bar on Home and the full basket screen.
- Set or remove a budget. Money is represented as integer pence, with GBP formatting.
- Search products in the active basket and filter to products still to pick.
- Save the current basket as a reusable shopping list, then choose and review how to reuse it.
- Read simple tips based on the basket and budget. These are local rules, not AI recommendations or live store offers.
- Restore the current basket, budget, and saved lists after restarting the app.

Cart changes flow through one `CartStore`, so the home and full-cart screens display the same state. Forms and layouts are designed for phone screens, keyboard input, and larger text.

## Using Carty

- **Home** shows the budget summary, a shopping tip, the first three basket products, and saved-list shortcuts. Use **View all** beside the shopping list to open the full basket, where **Search your basket** matches product names and **To pick** shows only products with quantity zero. Search covers the active basket only.
- **Lists** shows saved shopping lists. Save the current basket from this tab or with **Save as list** on either shopping screen; reuse a saved list or delete it after confirmation.
- **Tips** expands the local shopping guidance, including budget progress, products waiting to be picked, and reminders to check saved prices.

Set a product's quantity to zero to keep it on the list without adding to the total. Increase its quantity as you pick it up. Deleting a product removes it from the basket entirely.

To reuse a saved list, choose **Duplicate list** to copy its products, prices, quantities, and budget, or **Start fresh** to keep its products and prices while resetting every quantity to zero and clearing the budget. Continue to **Review list**, check the products, starting total, and budget, then select **Use this list**. Only that final action replaces the active basket and budget; backing out before applying leaves them unchanged. The saved original stays unchanged when you edit the new basket. Saved prices are the last prices entered when the list was saved, so check them against shelf labels as you shop.

## Run locally

The project is currently tested with **Flutter 3.29.0 / Dart 3.7.0**. Use that Flutter version to match CI. Install the Android or iOS toolchain for your target device, then run:

```sh
flutter doctor
flutter pub get
flutter run
```

For iOS, use a Mac with Xcode and CocoaPods configured. Open `ios/Runner.xcworkspace` when working in Xcode. Keep the Podfile, lockfile, and intentional Xcode project changes together in version control; generated `Pods` contents do not belong in Git.

## Check changes

```sh
dart format lib test
flutter analyze
flutter test
```

GitHub Actions checks formatting, analysis, and tests on pushes and pull requests. Tests should protect user-visible behavior: accurate totals, valid edits, state shared across screens, saved-list reuse, and storage failure handling.

## Development workflow

Follow [AGENTS.md](AGENTS.md): build small, working milestones and commit each with its relevant regression tests. Format, analyze, and run appropriate tests before committing; check documentation-only diffs. Use concise commit messages, preserve unrelated work, and push only when publishing has been authorized.

## Local toolchain troubleshooting

Native verification depends on the installed toolchain. In this development environment:

- If Android Studio shows undefined colour constants or widget parameters in `home.dart` while `flutter analyze` is clean, open **Dart Analysis** and select **Restart Dart Analysis Server**. This refreshes stale diagnostics after changes made outside the IDE. A hot restart may also be needed after changing a widget from stateless to stateful.
- An Android debug build selected Android Studio's bundled JBR **25.0.3** and failed in Gradle with the error `25.0.3`. A debug build succeeded using the installed **Java 21** runtime instead. Use a compatible installed JDK for that command: from `android/`, run `JAVA_HOME=/path/to/installed/jdk ./gradlew :app:assembleDebug`, replacing the path with the actual JDK home. This sets Java for that command only. The app pins Android NDK **27.0.12077973** to match its storage plugin; Gradle installs missing SDK components on the first build when the SDK licenses are already accepted.
- With Xcode **16.2**, both the simulator build and the device build without code signing failed with `Failed to launch AssetCatalogSimulatorAgent via CoreSimulator spawn`. Native iOS verification is pending repair of the local Xcode/CoreSimulator tooling and a successful rebuild; no app-code workaround has been applied for that failure.

Passing Dart analysis and Flutter tests does not by itself confirm that native Android or iOS builds pass.

## Code structure

```text
lib/
  core/       Money parsing and formatting
  models/     Immutable cart items and saved shopping lists
  state/      CartStore: basket actions, derived totals, and persistence coordination
  data/       CartStorage interface and local storage implementation
  screens/    Home navigation, full basket, and saved-list choice/review flow
  widgets/    Forms, cart tiles, budget summary, lists, and tips
  base/res/   Shared theme and styles
```

`CartStore` extends Flutter's `ChangeNotifier`. Screens listen to it and submit actions to it; widgets do not mutate item records. Text controllers and focus belong to the UI, while the store owns shopping data. A `CartStorage` interface keeps persistence replaceable and allows tests to use in-memory storage.

Prices are stored as pence rather than floating-point pounds. Totals and remaining budget are derived from items instead of being maintained as a second copy of the same information. Stable item IDs make edits independent of list positions.

## Local data and limitations

This MVP saves the basket, budget, and saved lists in a versioned JSON snapshot on the device using `shared_preferences`. It is convenient storage for a small personal basket and saved lists, not a durable financial record or backup service. Device removal, app-data clearing, or uninstalling the app can lose data.

Save failures show a **Retry** action; keep the app open while resolving them. If saved data cannot be read, Carty preserves it and blocks replacement writes. **Retry** can try loading it again before local edits are made. A confirmed **Reset saved data** allows the current basket and lists to replace the unreadable snapshot.

There are no accounts, cloud sync, live retailer prices, barcode scanning, AI calls, or shopping-history records in this stage. Prices are entered by the user, and a basket total is an estimate of the checkout amount. The app currently supports GBP only.

## Product direction and release preparation

See [the mockup gap analysis](docs/MOCKUP_GAP_ANALYSIS.md) for what matches the three reference images and what remains, and [the roadmap](docs/ROADMAP.md) for the next stages and the choices behind them. The green brand and functional Home, Lists, and Tips navigation adapt the references to the current local MVP. Product avatars are icon hints rather than catalog photos; scanning, price refresh, and the mockups' advanced recommendations still need their supporting data and integrations.

Before a store release, configure production Android signing, confirm app identifiers and iOS signing, finish the app icons and store metadata, and test on physical Android and iOS devices. The existing Android release configuration uses a debug key and must be replaced for publishing. Review platform minimum versions and privacy disclosures when adding new plugins. A Flutter SDK upgrade is a separate, tested migration; it is not required to understand or continue this MVP.
