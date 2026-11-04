# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Clinic management app (`ramzan`): Flutter + Firebase. Three roles: Reception (web, offline-capable), Doctor and Admin (Android, iOS, web). Two departments today (Eye, Homeopathy), more addable by Admin.

## Docs are the source of truth

Read before writing code. If code and docs disagree, the docs win; if a requirement is missing, it is not a requirement yet. Propose a doc change first, then code.

| Doc | Owns |
|---|---|
| `docs/FEATURES.md` | What the app does: roles, permissions, data model, every feature per role, out of scope. |
| `docs/FIREBASE_ARCHITECTURE.md` | Collections and fields, Cloud Functions, security rules, Storage layout, indexes, offline strategy, cost budget (§11). |
| `docs/DEVELOPMENT_PLAN.md` | State management, folder layout, packages, build phases and their status (§6), testing strategy, coding conventions. |
| `docs/UI_DESIGN.md` | Screen inventory, navigation map with phase per route, shell layouts, form layouts. |

When a decision is made in conversation, write it into the relevant doc (decisions table plus the affected section) in the same change as the code, dated.

## Working with the owner

- Ask requirement questions as selectable options, never assume.
- Each build phase ends with the owner reviewing screens. Do not call a phase done before that.
- Deploys (`firebase deploy ...`) are run by the owner, not by AI sessions; the permission layer blocks them anyway. Hand the owner the exact commands.

## Commands

```sh
flutter pub get
flutter analyze                                  # strict analyzer (analysis_options.yaml); must be clean
dart format lib test integration_test
flutter test                                     # unit + widget, no Firebase
flutter test test/features/users/users_vm_test.dart          # one file
flutter test --name "deactivate"                 # tests matching a name
cd functions && npm run build                    # tsc; the emulator serves lib/, so rebuild after editing src/
cd functions && npm test                         # Functions + rules tests inside emulators:exec
cd functions && firebase emulators:exec --only firestore,auth,storage "npx jest test/rules.test.ts"   # one Jest file
tool/integration_test_web.sh                     # every integration_test/*_test.dart on headless Chrome + emulators
tool/integration_test_web.sh --no-headless       # same, visible Chrome window
```

Run the app against the emulators instead of the live project:

```sh
firebase emulators:start                         # Auth 9099, Firestore 8080, Functions 5001, Storage 9199, UI 4000
node functions/scripts/seed-emulator.js          # accounts (SEED array: admin@clinic.test / Admin12345 etc.) + catalog
flutter run -d chrome --dart-define=USE_EMULATORS=true
```

Run `flutter analyze`, `flutter test` and `cd functions && npm test` before saying a change is done; run the integration script when a flow changed.

## Architecture

Summary; details in DEVELOPMENT_PLAN §4–§8.

- Feature-first clean architecture: `lib/features/<feature>/{domain,data,presentation}`. Shared code in `lib/core/`. State is `provider` + `ChangeNotifier` view models; no Riverpod, Bloc, GetX, `freezed` or `build_runner`. Models are plain Dart with hand-written `fromMap`/`toMap`/`copyWith` in `data/models/`.
- Firestore types never leave `data/`. Repository interfaces live in `domain/repositories/`, implementations take `FirebaseFirestore`/`FirebaseAuth`/`FirebaseFunctions` instances and throw `AppException` (`core/errors/`, `mapFirestoreError`). Uploads go through the `FileStore` abstraction in `core/storage/`.
- Money is `int` PKR. Clinic-day dates are `YYYY-MM-DD` strings from `KarachiDate` only. Soft deletes only (`deleted`, `deletedAt`, `deletedBy`, `deleteReason`). Every business document carries `branchId` (default `main`). Every write that must survive offline is a `WriteBatch` built in the repository. Writes stamp `createdBy`/`updatedBy` with the caller's uid; rules check them.
- Cost target: stay inside Firebase no-cost quotas at 500 visits a day. Check FIREBASE_ARCHITECTURE §11 before adding a listener, trigger or file upload.

### How the pieces connect

- `main.dart` builds the Provider tree: repositories, then `SessionController` (auth state + active role), then `SettingsController` (watches `settings/general` while signed in; gives the shell its clinic name and the Admin first-run banner). `app.dart` builds the `GoRouter` from `core/routing/app_router.dart`.
- Routing: `redirectFor(session, location)` is pure and unit-tested; it handles splash → login → forced password change → role home and the `from` return path. Each role has a `ShellRoute` wrapping `AppShell` (sidebar / rail / bottom bar by width); `_screenFor` maps sidebar paths to screens, unbuilt ones get `PlaceholderScreen` ("X — coming soon", which integration tests assert on). Extra Admin pages live in `_adminRoutes()`. All paths are constants in `app_routes.dart`.
- Screens come in pairs: `FooScreen` creates the view model from context and renders `FooView`, which only reads the view model. Widget tests pump `FooView` with a mocked or fake view model dependency. Interactive widgets carry `Key('...')` names that both widget and integration tests use.
- Admin writes to users go through callables (`createUser`, `setUserRoles`, `resetUserPassword`), which also keep `doctors.userId` in step with `users.doctorId`. Everything else Admin edits (settings, catalog) is written directly under rules.
- Cloud Functions (`functions/src/`, TypeScript, 2nd gen): each callable is `onCall(wrap(fooCore))` where `fooCore(deps, callerUid, callerClaims, data)` is pure enough to test against the emulators; `validation.ts` turns raw input into typed input or `invalid-argument`. Roles are custom claims; rules read `request.auth.token.roles`, not the user document.
- Test helpers in `test/helpers/fakes.dart`: `FakeAuthRepository`, `FakeSettingsRepository`, `stubbedCatalog()`, sample entities, `signedInSession()`, `wrapWithProviders()`. Functions tests clear the emulators over REST in `beforeEach`; rules tests load `firestore.rules` from the repo root.
- Integration tests (Chrome, emulators) never call `pumpAndSettle` (focused fields never settle on web); use the `waitFor` helpers in `integration_test/support.dart`. Files run in name order inside one emulator session, so `admin_setup_flow_test.dart` runs first and creates `settings/general`, which the seed deliberately leaves missing.
- Dev helper: a debug-only "Create test admin" button on the login screen (admin@mytester.com / 1234567890, `createTestAdmin` callable gated by `ALLOW_TEST_ADMIN` in `functions/.env`). Phase 9 removes it.

## Firebase

- Project `ramzan-clinic-web`, Firestore and Functions in `asia-south1`, Storage bucket in `us-central1` (not yet created on the live project), Blaze plan. `lib/firebase_options.dart` is generated; do not hand-edit.
- The app talks to the live project in development unless `USE_EMULATORS=true`. All tests use the local Emulator Suite, never live data.
- Rules are opened collection by collection per phase in `firestore.rules` and `storage.rules`; anything unmatched is denied. Add rules tests in `functions/test/rules.test.ts` with each new collection.
- App IDs: `ramzan.shop.ramzan`. Launcher name and browser title: Clinic.

## Current status

Phase 0 done. Phase 1 (Auth and users) and Phase 2 (Admin master data: settings, first-run setup, departments, doctors, visit types, fee grid, doctor picker in the user form) are built and verified as of 4 Nov 2026 (192 Flutter tests, 90 Functions/rules tests, 7 integration flows in two files). Both await owner screen review and the first deploy of Functions, Firestore rules and Storage rules. Next: Phase 3 (Patients and families). Phase list and per-phase status in DEVELOPMENT_PLAN §6.
