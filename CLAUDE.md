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
cd functions && npm run lint                     # tsc --noEmit
cd functions && npm test                         # Functions + rules tests inside emulators:exec
cd functions && firebase emulators:exec --only firestore,auth,storage "npx jest test/rules.test.ts"   # one Jest file (storage.test.ts covers storage.rules)
tool/integration_test_web.sh                     # every integration_test/*_test.dart on headless Chrome + emulators
tool/integration_test_web.sh --no-headless       # same, visible Chrome window
                                                 # the script rebuilds functions first; extra flags go to flutter drive (window is 1280x800)
```

One integration file (the script downloads ChromeDriver into `.dart_tool/chromedriver` on first run; start it on port 4444 yourself, then):

```sh
firebase emulators:exec --only auth,firestore,functions,storage \
  "node functions/scripts/seed-emulator.js && flutter drive --driver=test_driver/integration_test.dart \
   --target=integration_test/login_flow_test.dart -d web-server --dart-define=USE_EMULATORS=true"
```

If the owner's Emulator Suite is already up (`lsof -nP -iTCP:8080 -sTCP:LISTEN`), the `emulators:exec` wrappers fail with "port taken". Run against it directly, then re-seed, because the Jest suites clear Firestore and Storage:

```sh
cd functions && npx jest --runInBand                                   # all Functions + rules tests
curl -X DELETE "http://127.0.0.1:8080/emulator/v1/projects/ramzan-clinic-web/databases/(default)/documents"   # wipe Firestore
node functions/scripts/seed-emulator.js
.dart_tool/chromedriver/chromedriver/*/chromedriver-mac-arm64/chromedriver --port=4444 &   # absolute path, then per file:
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/login_flow_test.dart -d web-server --browser-dimension=1280x800 --dart-define=USE_EMULATORS=true
```

Run the app against the emulators instead of the live project:

```sh
firebase emulators:start                         # Auth 9099, Firestore 8080, Functions 5001, Storage 9199, UI 4000
node functions/scripts/seed-emulator.js          # accounts (SEED array: admin@clinic.test / Admin12345, reception@clinic.test / Reception12345 etc.) + catalog + one family
flutter run -d chrome --dart-define=USE_EMULATORS=true
```

Run `flutter analyze`, `flutter test` and `cd functions && npm test` before saying a change is done; run the integration script when a flow changed.

Analyzer rules that bite (`analysis_options.yaml`): strict casts/inference/raw types, `prefer_final_locals`, `require_trailing_commas`, `prefer_single_quotes`, `unawaited_futures`, `directives_ordering`, `sort_pub_dependencies`, no `dynamic` calls. Dart 3.13 also wants null-aware elements (`[?maybe]`, `{'k': ?maybe}`) and `required this._field` instead of assigning a private field in the initializer list.

## Architecture

Summary; details in DEVELOPMENT_PLAN §4–§8.

- Feature-first clean architecture: `lib/features/<feature>/{domain,data,presentation}`. Shared code in `lib/core/`. State is `provider` + `ChangeNotifier` view models; no Riverpod, Bloc, GetX, `freezed` or `build_runner`. Models are plain Dart with hand-written `fromMap`/`toMap`/`copyWith` in `data/models/`.
- Firestore types never leave `data/`. Repository interfaces live in `domain/repositories/`, implementations take `FirebaseFirestore`/`FirebaseAuth`/`FirebaseFunctions` instances and throw `AppException` (`core/errors/`, `mapFirestoreError`). Uploads go through the `FileStore` abstraction in `core/storage/`.
- Money is `int` PKR. Clinic-day dates are `YYYY-MM-DD` strings from `KarachiDate` only. Soft deletes only (`deleted`, `deletedAt`, `deletedBy`, `deleteReason`). Every business document carries `branchId` (default `main`). Every write that must survive offline is a `WriteBatch` built in the repository. Writes stamp `createdBy`/`updatedBy` with the caller's uid; rules check them.
- Cost target: stay inside Firebase no-cost quotas at 500 visits a day. Check FIREBASE_ARCHITECTURE §11 before adding a listener, trigger or file upload.

### How the pieces connect

- `main.dart` builds the Provider tree: repositories, then `SessionController` (auth state + active role), then `SettingsController` (watches `settings/general` while signed in; gives the shell its clinic name and the Admin first-run banner) and `PatientSyncController` (reception sessions: delta-pulls `patients`/`families` changed since the device's stored watermark at sign-in and every 5 minutes; no full download, no collection listeners). `app.dart` builds the `GoRouter` from `core/routing/app_router.dart`.
- Routing: `redirectFor(session, location)` is pure and unit-tested; it handles splash → login → forced password change → role home and the `from` return path. Each role has a `ShellRoute` wrapping `AppShell` (sidebar / rail / bottom bar by width); `_screenFor` maps sidebar paths to screens, unbuilt ones get `PlaceholderScreen` ("X — coming soon", which integration tests assert on). Extra Admin pages live in `_adminRoutes()`. All paths are constants in `app_routes.dart`.
- Screens come in pairs: `FooScreen` creates the view model from context and renders `FooView`, which only reads the view model. Widget tests pump `FooView` with a mocked or fake view model dependency. Interactive widgets carry `Key('...')` names that both widget and integration tests use.
- Admin writes to users go through callables (`createUser`, `setUserRoles`, `resetUserPassword`), which also keep `doctors.userId` in step with `users.doctorId`. Everything else (settings, catalog, families, patients) is written directly under rules; Firestore triggers (`assignPatientNo`, `checkDuplicateFamilyPhone`) fill in the functions-only fields afterwards, and rules lock those fields against clients.
- Cloud Functions (`functions/src/`, TypeScript, 2nd gen): each callable is `onCall(wrap(fooCore))` where `fooCore(deps, callerUid, callerClaims, data)` is pure enough to test against the emulators; `validation.ts` turns raw input into typed input or `invalid-argument`. Roles are custom claims; rules read `request.auth.token.roles`, not the user document.
- Test helpers in `test/helpers/fakes.dart`: `FakeAuthRepository`, `FakeSettingsRepository`, mocktail mocks per repository with `register*Fallbacks()`, `stubbedCatalog()`, sample entities and builders (`sampleVisit`, `samplePrescription`, `sampleOperation`, `sampleReport`), `signedInSession()`, `wrapWithProviders()`. Functions tests clear the emulators over REST in `beforeEach`; rules tests load `firestore.rules` / `storage.rules` from the repo root.
- Patient and visit screens take a `role` and are mounted under both `/reception/...` and `/admin/...` (`_patientRoutes`, `_visitRoutes`; paths from `AppRoutes.patientsFor` etc.). Doctor pages (`/doctor/visits/:id`, `/doctor/patients/:id`, `/doctor/operations/:id`) come from `_doctorRoutes()`; `PatientSearchScreen(role: doctor)` is read-only.
- Live data is held once, high in the tree: `TodayVisitsController` keeps the single listener on today's visits (whole day for reception/admin, the doctor's own for doctor-only sessions via `scopedDoctorId`) that the visits list, both queues, the shift summary, `SyncBadge` and the new-visit "waiting now" count read. Start/Complete logic shared by the reception board and the doctor queue is the `VisitStatusActions` mixin.
- Patient history is paged, never subscribed: `PatientHistoryViewModel` (`features/visits/presentation/viewmodels/`) reads 3 visits per page through `VisitsRepository.patientVisitsPage` plus their prescriptions through `getPrescriptions`, only once the History or Visits tab is built (`PatientHistoryLoader`); "Load more" (`history-load-more`, `visits-load-more`) reads the next 3. Consultation, the doctor's patient page and the reception patient page all share it.
- Patient search is local-first: `PatientsRepository` searches take a `ReadSource` (`core/read_source.dart`); `PatientSearchViewModel` asks the cache first, the server on a miss or when a phone search returns fewer members than the family's `patientCount` (results land in the cache), and offers `searchOnline()` (the `search-online` footer). Test stubs must match `source: any(named: 'source')`.
- Firestore resolves a write's future only on server acknowledgement, so repositories wrap every write that must work offline in `commitOrQueue` (`core/firebase/offline_write.dart`): wait 1.5 s, then treat it as queued.
- Doctor-side code is split by collection, not by role: `features/prescriptions/` (Rx entity, `EyeFields`/`PrescriptionRules`/`FollowUp`, consultation, prescription PDF), `features/reports/` (`ReportFiles`, repository over `FileStore` + `ImageShrinker`, `ReportsTab`), `features/operations/` (`OperationRules`/`PostOp`, schedule sheet, list, detail, Me-tab defaults editor), while the doctor queue and summary live in `features/visits/` and the history page in `features/patients/`.
- Multi-document writes are one `WriteBatch` in the repository: a prescription save writes the Rx (id = visit id), `visits.hasPrescription` (+ completion) and its follow-up appointment; scheduling an operation writes the operation, a `source: operation` appointment on the surgery day and one `postOp` appointment per day, all regenerated when the date or days change; a visit created from an appointment's Arrived button (`/<role>/visits/new?patientId=&appointmentId=&doctorId=`, `VisitInput.appointmentId`) marks that appointment `arrived` with the visit id in the visit batch (rules require `visitId` for `arrived`).
- `features/appointments/` (Phase 6A): `AppointmentRules` (booking validation, row actions by source/status/day: surgery-day rows get Arrived and No-show only), `AppointmentsRepository` (`watchDay`, `watchPatientAppointments`, `book`, `reschedule`, `cancel`, `markNoShow`; `date ==` / `patientId ==` queries sorted on the client, no index), `AppointmentsDayViewModel` + `AppointmentsView` (date picker, one column per doctor, mounted at `/reception/appointments` and `/admin/appointments`), `BookAppointmentViewModel` + `BookAppointmentView` (`/<role>/appointments/new?patientId=`, reached from the search row `patient-book-<id>` and the patient page tab), `PatientAppointmentsTab` on the patient page. Phase 6B: `ReminderRules`/`ReminderMessage` (sections tomorrow / follow-ups due / post-op due / overdue, template placeholders), `remindersWindow` (one date-range read, no listener) + `markReminderSent`, `RemindersView` at `/reception/reminders` (Send goes through an injected `openUrl`, so widget tests never open WhatsApp), `doctorUpcoming` (index `appointments(doctorId, date)`) + `DoctorAppointmentsView` at `/doctor/appointments` (non-primary doctor destination, under More on phones), and `PostOpDaysSheet` (`features/operations/presentation/widgets/`) opened from booked post-op rows; a days-only `OperationsRepository.reschedule` keeps the surgery appointment so the operation update stays inside the reception rule.
- `features/inventory/` (Phase 7A): `LensPower`/`LensGrid` (one `inventoryItems` document per lens type and power, document ID = `lensKey`, grid SPH −20…+20 / CYL 0…−8 in 0.25 steps), `InventoryRules`, `PurchaseRules`, `InventoryRepository` (every stock change is a batch that also writes a `stockMovements` row; a purchase batch also writes the `expenses` document; purchases are immutable). `InventoryController` in `main.dart` holds the one `inventoryItems` listener for reception and admin sessions; the category lists, lens grid, low-stock filter, item form/detail and the purchase item picker read from it. Admin pages: `/admin/inventory` → `/admin/inventory/medicine`; tabs are routes (`InventoryTab`), item routes under `/admin/inventory/items/...` (lens IDs are URL-encoded by `AppRoutes.adminInventoryItem`). `features/finance/` holds only the `Expense` entity and model until Phase 8.
- `features/sales/` (Phase 7B): `Sale`/`SaleLine`, `SaleRules`, `LensSuggestion` (latest eye prescription → on-grid powers per eye), `SalesRepository` (`createSale` batch = sale document + `stock` decrement + `sale` movement per line; `voidSale` batch = soft delete + increments + positive movements; `watchDay` is a `date ==` listener held only while the Sales page is open; `saleForVisit` is a `visitId ==` read). Screens are mounted under both `/reception/sales` and `/admin/sales` (`_salesRoutes`; Admin's Sales destination is non-primary): list, `NewSaleView` (walk-in when no `patientId`; `LensPickerSheet` reuses `LensGridTable` from `features/inventory/presentation/widgets/`), `SaleDetailView` (print; Admin void via `VoidSaleDialog`). `VisitDetailViewModel` takes an optional `SalesRepository` to show and print the linked sale's items (`ReceiptPdf.build(sale:)`); `SaleReceiptPdf` reuses the receipt header, blocks and items table. Sell buttons: `patient-sell-<id>` (search row), `patient-sell` (patient page), `visit-sell` (visit detail).
- Dialogs opened from a page inside a role shell must pop with the dialog builder's own context (`builder: (dialog) => ... Navigator.of(dialog).pop()`): the page lives in the `ShellRoute`'s nested navigator, so popping with the page context pops the page. Widget tests use a single navigator and do not catch this; the Chrome flows do. In Chrome flows, the shell's snackbar covers a tab's FAB while it shows, so `waitForGone` the snackbar text before tapping the next FAB; wrap a flow in `reportingFlutterErrors` to see Flutter error details in the failure message.
- PDFs (`pdf` package) are built on the client and printed through the `ReceiptPrinter` abstraction (`FakeReceiptPrinter` in tests). File and camera pickers sit behind typedefs (`LogoPicker`, `ReportPicker`) and image resizing behind `ImageShrinker`, so widget tests inject bytes; the browser file dialog cannot be driven from Chrome integration tests.
- Integration tests (Chrome, emulators) never call `pumpAndSettle` (focused fields never settle on web); use the `waitFor` helpers in `integration_test/support.dart`. On web a TextField that was submitted loses focus and a later `enterText` into it is silently dropped, so tap the field (or its keyed clear button) before typing again. Files run in name order inside one emulator session: `admin_inventory_flow_test.dart` runs first (it needs no settings and expects Medicines empty and the −1.25 / −0.50 lens unstocked), then `admin_setup_flow_test.dart` creates `settings/general`, which the seed deliberately leaves missing. The seed stocks three items (an Eye Drops consumable, a frame, the −2.00 / −0.75 single-vision lens) for `reception_sales_flow_test.dart`.
- `bootstrapFirebase()` (`core/firebase/firebase_bootstrap.dart`) initialises Firebase once, turns on offline persistence everywhere and, when `USE_EMULATORS=true`, points Auth/Firestore/Functions/Storage at the emulator ports (Android uses `10.0.2.2`). Functions region constant lives there too. Local preferences go through `KeyValueStore` (`core/storage/`), with `InMemoryKeyValueStore` for tests.
- `.github/modernize/` is unrelated Java-upgrade tooling left behind by an IDE; ignore it.
- Dev helper: a debug-only "Create test admin" button on the login screen (admin@mytester.com / 1234567890, `createTestAdmin` callable gated by `ALLOW_TEST_ADMIN` in `functions/.env`). Phase 9 removes it.

## Firebase

- Project `ramzan-clinic-web`, Firestore and Functions in `asia-south1`, Storage bucket in `us-central1` (not yet created on the live project), Blaze plan. `lib/firebase_options.dart` is generated; do not hand-edit.
- The app talks to the live project in development unless `USE_EMULATORS=true`. All tests use the local Emulator Suite, never live data.
- Rules are opened collection by collection per phase in `firestore.rules` and `storage.rules`; anything unmatched is denied. Add rules tests in `functions/test/rules.test.ts` (Firestore) or `functions/test/storage.test.ts` (Storage) with each new collection or path. Rules can read `request.time` and parse the stored `YYYY-MM-DD` (`timestamp.date(...)`): the prescription same-day edit window works that way.
- Composite indexes live in `firestore.indexes.json` (two: `visits(doctorId, status, deleted, date)` for the doctor's aggregate summary and `visits(patientId, deleted, createdAtLocal desc)` for the paged patient history). Most list queries use one equality or `arrayContains` filter and filter `deleted`/sort in the client on purpose. Add an index there, not in the console, when a query needs one.
- Functions tests get emulator hosts and the project id from `functions/test/setup.ts`; `functions/.env` holds `ALLOW_TEST_ADMIN` and is read by the emulator and by deploys.
- App IDs: `ramzan.shop.ramzan`. Launcher name and browser title: Clinic.

## Current status

Phases 0–7 are built and verified as of 6 Nov 2026 (Phase 5 in two checkpoints: 5A doctor queue, consultation, prescriptions, history, summary; 5B reports, operations, operation-type defaults; Phase 6 in two: 6A booking, appointments day view, Arrived → visit, patient Appointments tab; 6B reminders due today, doctor's upcoming appointments, reception post-op days; Phase 7 in two: 7A Admin inventory — items by category, lens grid, suppliers, purchase bills that create an expense, adjustments, movement history, low-stock filter; 7B sales — reception and admin sales with the lens picker, walk-in customers, receipts, stock deduction, today's list, Admin void). Phases 1–7 await the owner's screen review and the first deploy of Functions, Firestore rules, indexes and Storage rules. Next: Phase 8 (finance and analytics). Per-phase status, decisions and test counts are in DEVELOPMENT_PLAN §1 and §6; screen keys in UI_DESIGN §4. Integration flows: ten files, run in name order.
