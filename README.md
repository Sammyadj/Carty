# Carty

Carty is a Flutter shopping companion for keeping track of the cost of a basket and staying within a budget. It is being developed in small, understandable stages: a dependable manual shopping flow first, then useful automation.

## Current MVP

- Add products with a name, unit price, and quantity; edit or remove them later.
- See a live basket total, remaining budget, progress, and an explicit over-budget status.
- Keep the total, remaining budget, and Add item control visible in a bottom bar on both shopping screens.
- Set or remove a budget. Money is represented as integer pence, with GBP formatting.
- Keep products at quantity zero as a reminder to pick them up. They do not count towards the total until their quantity increases.
- Save the current basket as a reusable shopping list.
- Reuse a list in either of two ways: duplicate its quantities and budget, or keep its products and prices while resetting quantities to zero and removing the budget.
- Preserve the saved original when changing a basket created from it.
- Read simple tips based on the basket and budget. These are local rules, not AI recommendations or live store offers.
- Restore the current basket, budget, and saved lists after restarting the app.

Cart changes flow through one `CartStore`, so the home and full-cart screens display the same state. Forms and layouts are designed for phone screens, keyboard input, and larger text.

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

## Local toolchain troubleshooting

Native verification depends on the installed toolchain. In this development environment:

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
  screens/    Home and full-cart screens
  widgets/    Forms, cart tiles, budget summary, lists, and tips
  base/res/   Shared theme and styles
```

`CartStore` extends Flutter's `ChangeNotifier`. Screens listen to it and submit actions to it; widgets do not mutate item records. Text controllers and focus belong to the UI, while the store owns shopping data. A `CartStorage` interface keeps persistence replaceable and allows tests to use in-memory storage.

Prices are stored as pence rather than floating-point pounds. Totals and remaining budget are derived from items instead of being maintained as a second copy of the same information. Stable item IDs make edits independent of list positions.

## Local data and limitations

This MVP saves a versioned JSON snapshot using `shared_preferences`. It is convenient storage for a small personal basket and saved lists, not a durable financial record or backup service. Saving can fail, and device removal, app-data clearing, or uninstalling the app can lose data. Storage errors are surfaced in the app for retry.

There are no accounts, cloud sync, live retailer prices, barcode scanning, AI calls, or shopping-history records in this stage. Prices are entered by the user, and a basket total is an estimate of the checkout amount. The app currently supports GBP only.

## Product direction and release preparation

See [the roadmap](docs/ROADMAP.md) for the next stages and the choices behind them.

Before a store release, configure production Android signing, confirm app identifiers and iOS signing, finish the app icons and store metadata, and test on physical Android and iOS devices. The existing Android release configuration uses a debug key and must be replaced for publishing. Review platform minimum versions and privacy disclosures when adding new plugins. A Flutter SDK upgrade is a separate, tested migration; it is not required to understand or continue this MVP.
