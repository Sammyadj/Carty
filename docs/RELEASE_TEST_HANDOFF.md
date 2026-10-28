# Release-test checkpoint — 28 October 2026

Development has since resumed by user request. This document records the test
checkpoint; the current scope is tracked in `IMPLEMENTATION_PROGRESS.md`.
City was integrated into `main` in PR #1; subsequent development uses focused
feature branches and pull requests as described in `../CONTRIBUTING.md`.
The user confirmed there is no email provider or sender domain yet.

The user asked to wrap up, commit/push important work and test a physical iPhone
Release build before authorising further development, which is now authorised.
City remains the selected app design.

## Resume context

- Remote: `Sammyadj/Carty`. The City/cloud checkpoint was merged into `main`
  through PR #1. Android signing was merged through PR #2.
- Workspace: `/Users/samueladjei/StudioProjects/Carty_app`.
- Latest code milestone: `f396404` (household device-copy recovery), following
  `8df40de` (member/access controls) and `6caeaa1` (their documentation).
- The complete scope remains in `IMPLEMENTATION_PROGRESS.md`. Planning/shopping,
  categories, private recommendations, Lists/History and durable local/private
  cloud records are implemented. Household roles, invitations, editing,
  offline/conflict handling and recovery UI are implemented and automated-tested.
- Invitations are addressed by verified email but appear **in app only**; no
  notification email is sent. Supabase's default sign-in email service is still
  test-team limited. Production SMTP/domain/provider configuration is pending.
- Supabase project: `igytgwdxljbnxfjtufui`, London. Five migrations are applied;
  do not reapply or rename them. No schema change was needed for recovery UI.
- Preserve unrelated Xcode edits in the main checkout at
  `/Users/samueladjei/StudioProjects/Carty_app`.

## Verified checkpoint

- Flutter 3.47.8 / Dart 3.13.7 at
  `/Users/samueladjei/Development/flutter/bin`.
- All 367 tests pass; `flutter analyze --no-pub` reports no issues.
- Formatting passes and `git diff --check` is clean.
- `flutter build ios --release --no-pub` succeeds with automatic signing.
  Output: `build/ios/iphoneos/Runner.app` (19.9 MB).
- Bundle: `com.Samueladjei.cartyApp`, version `1.0.0+1`; development team
  `AWF9Q3DD6N`. This is a development-signed Release test build, not an App Store
  upload. Leave the shared Xcode Run scheme's Debug setting intact.
- Installed on Panda (iOS 26.7.2) using `devicectl`; launch succeeded without
  attaching a debugger. A subsequent process query confirmed Runner was running.
  This verifies installation/startup, not the user acceptance checklist below.
- Build logs note a future CocoaPods-to-Swift-Package-Manager migration. Defer it
  until after testing; the current build succeeds with the existing Podfile.

## Physical test pass

Test on Panda, reopening Carty from its home-screen icon without a debugger:

1. Cold launch and loading animation; create a plan, set budget and estimated
   quantities/prices; verify suggestions and horizontal categories.
2. Save, close/reopen and continue editing the same list; create another list
   with save-before-switch; verify the first one is retained.
3. Scan real barcodes; edit/rescan an incorrect match; confirm shelf prices,
   picked quantities, budget warnings and completed History.
4. Reopen previously loaded data offline, edit, then reconnect. Test private
   cloud conflicts and account switching without mixing workspaces.
5. Using authorised test accounts, accept an in-app household invitation; verify
   editor changes, viewer restrictions, offline conflicts and role revocation.
6. In household options, review/export a device copy, save a private copy and
   stage an older version for review. Verify the native file picker on phone.
   Only remove copies you deliberately intend to discard.
7. Check larger text, keyboard layouts and navigation; report screenshots and
   exact steps for any issue. Simulator/widget tests do not replace this pass.

To rebuild/install later with the verified local SDK:

```sh
/Users/samueladjei/Development/flutter/bin/flutter run --release -d <device-id>
```

Use the ID reported by `flutter devices`; Panda was reachable over the paired
connection at this checkpoint. Release mode permits normal icon launch.

## Work deferred until the user resumes

- Address findings from physical testing before adding features.
- Configure production sign-in/notification email with a verified sender and
  server-side credentials, actual delivery tests and abuse controls. A provider
  and sender-domain question is already pending; do not ask for secrets in chat.
- Finish real two-account/offline/file acceptance; review iOS signing/store
  privacy, screenshots, support/privacy URLs and Android production signing.
  Android Release now requires explicit upload-key configuration; the real
  owner key and Play setup remain pending. See `ANDROID_SIGNING.md`.
- Preserve the approved sharing defaults: email-addressed viewer/editor roles,
  only editors/owners change items, owner account deletion removes owned shared
  lists after a warning, GBP. Checkout/payments and retailer price integrations
  are future work.
- Private cloud paging/delta writes exist, but the client still hydrates the
  whole workspace and reviews whole-workspace conflicts. Shared saves send the
  full list (maximum 1,000 products) while updating changed database rows.

Build/test success does not establish production or App Store readiness.
