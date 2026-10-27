# Carty

This is the **UI exploration branch**. Use the Home toolbar's sliders icon (**Explore designs**) to compare City, Fresh, and Pantry while keeping the same shopping data. See [the visual comparison](docs/UI_EXPERIMENT.md) for rendered home/basket screens and the design references.

Carty is a Flutter shopping companion for keeping track of the cost of a basket and staying within a budget. It is being developed in small, understandable stages: a dependable manual shopping flow first, then useful automation.

## Current MVP

- Add products with a name, unit price, and quantity; edit or remove them later.
- Scan retail barcodes, look up products through Open Food Facts with a UPCitemdb general-retail fallback, then confirm the shelf price and quantity. Manual barcode entry and remembered product details cover missing matches.
- See a live basket total, remaining budget, and progress. Near-budget feedback starts at 80% of the budget; spending above the budget has an explicit over-budget status.
- Use a green Carty dashboard with product icon avatars and Home, Lists, and Tips navigation.
- Keep the total, budget status, Scan barcode, and Add item controls visible in a bottom bar on Home and the full basket screen.
- Set or remove a budget. Money is represented as integer pence, with GBP formatting.
- Search products in the active basket and filter to products still to pick.
- Save a named shopping list and continue editing it with automatic updates; duplicate it or start fresh for a separate shop.
- Read simple tips based on the basket and budget. These are local rules, not AI recommendations or live store offers.
- Restore the current basket, budget, saved lists, and the named list being edited after restarting the app.

Cart changes flow through one `CartStore`, so the home and full-cart screens display the same state. Forms and layouts are designed for phone screens, keyboard input, and larger text.

## Using Carty

Choose **Create new list** on Home or Lists, or use the **New list** toolbar action, to begin a different shop with an empty basket and no budget. If the current products or budget differ from every named saved list, Carty offers **Save and start new**, **Start without saving**, or **Cancel**. Cancelling the name form or a failed save keeps the current basket. Existing saved lists stay available. A budget-only basket can be cancelled or discarded; add products before saving it as a named list.

- **Home** shows the budget summary, a shopping tip, the first three basket products, and saved-list shortcuts. Use **View all** beside the shopping list to open the full basket, where **Search your basket** matches product names and **To pick** shows only products with quantity zero. Search covers the active basket only.
- **Lists** shows saved shopping lists. Save the current basket from this tab or with **Save as list** on either shopping screen. Continue editing a saved list, reuse its products in a separate basket, or delete it after confirmation. The list receiving your current edits is marked **Currently editing**.
- **Tips** expands the local shopping guidance, including budget progress, products waiting to be picked, and reminders to check saved prices.

Set a product's quantity to zero to keep it on the list without adding to the total. Increase its quantity as you pick it up. Deleting a product removes it from the basket entirely.

To carry on an existing shop, open its saved list and choose **Continue editing** (the default). Continue to **Review list**, check the products and budget, then confirm **Continue editing**. Quantities, prices, pending products, and budget are retained. Edits and new scans update that same named list automatically. **Editing [list name]** identifies it on Home and the full basket screen. Closing and reopening Carty restores this editing state, so you can prepare a list at home and carry on in the shop without duplicating it. Saving a basket by name also starts this ongoing editing mode.

Choose **Duplicate list** to copy products, prices, quantities, and budget into a separate basket, or **Start fresh** to copy the products and prices while resetting quantities to zero and clearing the budget. Review and confirm **Use this list**. These two modes keep the saved original unchanged. **Save a copy** creates another named version when you are already editing a saved list. Saved prices are your last entered prices; check them against shelf labels as you shop.

Opening a different list prompts **Save and switch**, **Switch without saving**, or **Cancel** when the current basket has no matching named list. Cancelling the prompt or name form keeps the current shop. Pending writes settle before switching; if saving fails, switching is blocked until a successful retry. **Create new list** and **Clear cart** leave the named list intact and detach the new basket. Deleting a named list keeps the current basket but stops updates to the deleted list. Removing its last product keeps the named list available for editing.

## Barcode scanning

Select **Scan barcode** on Home or in the full basket. Allow camera access, hold a retail barcode inside the frame, and review the matched name, brand, and pack size. Correct the name if needed, enter the shop's **Shelf price per item**, choose the quantity to add, and confirm **Add to basket**. A scan alone never adds an item. Prices are always entered by you; the catalog supplies product identity, not a live retailer price.

If the match is wrong, choose **Edit barcode** or **Scan again** directly on **Review product**. Editing starts with the current digits and validates the replacement. A different barcode loads a fresh review, clears the previous price, and resets the quantity to one. Cancelling either action or scanning the same barcode preserves your current entries. Your basket changes only after **Add to basket**.

**Enter barcode manually** accepts the printed digits when camera access is denied or unavailable. EAN-8, UPC-A, EAN-13, and GTIN-14 barcodes are checksum validated; QR codes and UPC-E are outside this first version. Carty checks its local cache first, then Open Food Facts, and tries UPCitemdb if the food service has no usable match or is unavailable. Unknown barcodes, failed connections, and busy lookups still allow manual names and prices. Confirming **Add to basket** remembers your reviewed name locally; cancelling does not teach a new product.

Scanning a product already in the basket combines its quantity with the existing line. The review explains that the newly confirmed unit price applies to the entire combined line. Barcode metadata survives restarts and saved-list reuse; ordinary manual products are not merged just because their names match.

The last 100 catalog matches and confirmed products share a private on-device cache for offline reuse. This includes manually identified products, even after they are removed from a basket. Old entries may be evicted as the cache fills. **Look up again** requests fresh product details, without changing your price. Lookups are spaced at least five seconds apart; UPCitemdb requests are spaced at least ten seconds apart and only one retail request runs at a time. Its key-free trial allows 100 requests daily and may enforce shared-network limits. Rate-limit cooldowns are respected across app restarts; busy or failed lookups allow manual entry. Cached details can become outdated, so review the packaging and shelf label.

The camera is opened only from the scanner screen. Camera images are processed on the device; Carty sends the barcode to [Open Food Facts](https://world.openfoodfacts.org/) and, if needed, [UPCitemdb](https://www.upcitemdb.com/api/), along with ordinary network request information. Basket contents, quantities, budgets, saved lists, and manually entered names are not uploaded. Sources are labelled in the review: Open Food Facts data is under the [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/); UPCitemdb data is subject to [its own terms](https://www.upcitemdb.com/terms). User-entered details are labelled separately. Product photographs and provider prices are not used. No paid API key or subscription is configured; evaluate real-shop coverage and service terms before scaling a public release.

## Run locally

The project is currently tested with **Flutter 3.47.8 / Dart 3.13.7**. Use that Flutter version to match CI. Install the Android or iOS toolchain for your target device, then run:

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

Scanner tests use a fake camera and HTTP client to cover duplicate detections, permission failures, lifecycle changes, product lookup, offline cache, manual fallback, and confirmed cart changes. Camera focus, flashlight behavior, permission settings, and detection speed still need checks on physical Android and iOS devices. Rebuild the app after adding the camera plugin; hot reload alone cannot install native plugins or permission descriptions. `mobile_scanner` remains pinned to the tested 7.0.0 version during the SDK migration.

## Development workflow

Launcher icons use Carty's green cart/checkmark artwork. Regenerate the iOS icon set, Android legacy and adaptive icons, and the 1024px preview with `python3 tool/generate_app_icons.py` (requires Pillow >= 10). Rebuild and install the app to update its home-screen icon; hot reload cannot update native launcher assets.

Follow [AGENTS.md](AGENTS.md): build small, working milestones and commit each with its relevant regression tests. Format, analyze, and run appropriate tests before committing; check documentation-only diffs. Use concise commit messages, preserve unrelated work, and push only when publishing has been authorized.

## Local toolchain troubleshooting

Native verification depends on the installed toolchain. In this development environment:

- If Android Studio shows undefined colour constants or widget parameters in `home.dart` while `flutter analyze` is clean, open **Dart Analysis** and select **Restart Dart Analysis Server**. This refreshes stale diagnostics after changes made outside the IDE. A hot restart may also be needed after changing a widget from stateless to stateful.
- An Android debug build selected Android Studio's bundled JBR **25.0.3** and failed in Gradle with the error `25.0.3`. A debug build succeeded using the installed **Java 21** runtime instead. Use a compatible installed JDK for that command: from `android/`, run `JAVA_HOME=/path/to/installed/jdk ./gradlew :app:assembleDebug`, replacing the path with the actual JDK home. This sets Java for that command only. The app pins Android NDK **27.0.12077973** to match its storage plugin; Gradle installs missing SDK components on the first build when the SDK licenses are already accepted.
- Android uses **Gradle 8.14.3 / AGP 8.11.1 / Kotlin 2.2.20**, with Android SDK 36 required by Flutter. A Java 21 debug build passes. These meet Flutter 3.47's minimum requirements; the tool warns that a future upgrade will need the newer AGP 9 toolchain.
- iOS requires **15.0 or newer**. Xcode **27.1** rejects the former iOS 12 deployment target. Change the Podfile and regenerate pods rather than editing generated Pods settings.
- With Flutter **3.47.8** and Xcode **27.1**, the generic `flutter build ios --simulator --debug` succeeds. The previous AssetCatalogSimulatorAgent and dual-architecture `lipo` failures did not recur. The phone Debug build also compiles; physical-device startup and hot reload must be verified with the phone connected and unlocked.

Passing Dart analysis and Flutter tests does not by itself confirm that native Android or iOS builds pass.

The old Flutter 3.29 / Dart 3.7 debug runtime aborted on the iOS 26 phone with `mprotect failed: 13 (Permission denied)`, matching [Flutter's tracked JIT compatibility issue](https://github.com/flutter/flutter/issues/163984). The project now uses the updated runtime, Flutter's generated LLDB initialization file, and the UIScene lifecycle. Keep Xcode's Runner scheme on **Run → Info → Debug**, with **Debug executable** enabled. Run `flutter pub get` and build once to regenerate ignored files under `ios/Flutter/ephemeral` after a fresh checkout; keep the shared scheme's LLDB path intact.

Use `flutter run -d <device-id>` for development. Wi-Fi startup on iOS 26 can be slow while Xcode prepares device-support symbols; connect USB for the initial setup if necessary. Accept local-network permission on the phone for debug discovery and hot reload. Release mode remains available for independent phone testing, but is no longer the intended workaround for the old runtime.

Flutter now links the scanner and preferences plugins through its generated Swift package. The existing custom CocoaPods integration remains as a compatibility scaffold and produces a migration advisory; both simulator and Android builds pass. Fully removing CocoaPods is a separate cleanup, not a requirement for this SDK upgrade.

## Code structure

```text
lib/
  core/       Money parsing and retail barcode validation
  models/     Immutable cart items, product details, and saved shopping lists
  state/      CartStore: basket actions, derived totals, and persistence coordination
  data/       Local cart storage and cached product lookup
  screens/    Home, basket, list reuse, barcode capture, and product review
  widgets/    Forms, cart tiles, budget summary, lists, and tips
  base/res/   Shared theme and styles
```

`CartStore` extends Flutter's `ChangeNotifier`. Screens listen to it and submit actions to it; widgets do not mutate item records. Text controllers and focus belong to the UI, while the store owns shopping data. A `CartStorage` interface keeps persistence replaceable and allows tests to use in-memory storage.

Prices are stored as pence rather than floating-point pounds. Totals and remaining budget are derived from items instead of being maintained as a second copy of the same information. Stable item IDs make edits independent of list positions.

## Local data and limitations

This MVP saves the basket, budget, and saved lists in a versioned JSON snapshot on the device using `shared_preferences`. It is convenient storage for a small personal basket and saved lists, not a durable financial record or backup service. Device removal, app-data clearing, or uninstalling the app can lose data.

Saved lists live in the app's private preferences, not as files in your Documents folder. The product cache uses a separate preferences key and can be discarded without altering the basket or saved lists. Version-2 snapshots also retain which named list is being edited. Existing version-1 baskets and saved lists, including ones without barcode metadata, remain readable and migrate on the next save. Old saved lists become linked for ongoing updates when you explicitly choose **Continue editing**.

Save failures show a **Retry** action; keep the app open while resolving them. If saved data cannot be read, Carty preserves it and blocks replacement writes. **Retry** can try loading it again before local edits are made. A confirmed **Reset saved data** allows the current basket and lists to replace the unreadable snapshot.

There are no accounts, cloud sync, live retailer prices, AI calls, or shopping-history records in this stage. Prices are entered by the user, and a basket total is an estimate of the checkout amount. The app currently supports GBP only.

## Product direction and release preparation

See [the mockup gap analysis](docs/MOCKUP_GAP_ANALYSIS.md) for what matches the three reference images and what remains, and [the roadmap](docs/ROADMAP.md) for the next stages and the choices behind them. The green brand, Home/Lists/Tips navigation, and barcode-to-review flow adapt the references to the current app. Product avatars are icon hints rather than catalog photos; live price refresh and the mockups' advanced recommendations still need their supporting data and integrations.

Before a store release, configure production Android signing, confirm app identifiers and iOS signing, finish the app icons and store metadata, and test on physical Android and iOS devices. The existing Android release configuration uses a debug key and must be replaced for publishing. Review platform minimum versions and privacy disclosures when adding new plugins. A Flutter SDK upgrade is a separate, tested migration; it is not required to understand or continue this MVP.
