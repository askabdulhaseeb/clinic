# Development Plan

Draft v12 — 6 Nov 2026. v12: Phase 10 decisions and build notes (deferred polish: report PDF, sales margins, version footer, theme colour). v11: Phase 6B decisions and build notes (reminders, doctor upcoming page, reception post-op days). v10: Phase 6 split into checkpoints 6A and 6B, Phase 6A decisions and build notes (booking from the patient, day view per doctor, Arrived through the new-visit form, patient Appointments tab). v9: Phase 5B decisions and build notes (reports with client resize, operations with appointments regenerated in one batch, doctor edits of operation-type defaults, visit–operation link). v8: Phase 5 split into checkpoints 5A and 5B, Phase 5A decisions and build notes (doctor queue on the shared today listener, consultation with Save / Complete, prescription PDF, follow-up appointments, aggregate summary). v7: Phase 4 decisions and build notes (visit flow, receipt PDF, queue, summary, sync badge, offline integration test). v6: Phase 3 built (families, patients, search, patient page, patient-number and duplicate-phone triggers, offline cache listeners). v5: Phase 2 built (settings, catalog, first-run setup, doctor picker, shared integration helpers). v4: budget decisions (Storage bucket us-central1, no backup, typed-only prescriptions, incremental summaries) applied to phases and setup steps. Companion to [FEATURES.md](FEATURES.md) and [FIREBASE_ARCHITECTURE.md](FIREBASE_ARCHITECTURE.md). This document fixes the technical choices for the Flutter code and the order in which features are built.

---

## 1. Decisions Summary

| Topic | Decision |
|---|---|
| State management | `provider` with `ChangeNotifier` view models. No Riverpod, Bloc, or GetX. |
| Architecture | Clean architecture, feature-first: each feature owns `domain/`, `data/`, `presentation/`. Shared code in `lib/core/`. |
| Models | Plain Dart. Hand-written `fromMap`, `toMap`, `copyWith`. No `freezed`, no `build_runner` for models. |
| Routing | `go_router`. URL paths on web, role-based redirect after login. |
| UI | Material 3, teal primary. Eye accent blue, Homeo accent green. Shells, navigation and form layouts in [UI_DESIGN.md](UI_DESIGN.md); screens reviewed one by one while building. |
| Theme details | Light + dark, follows system. Roboto (Flutter default). Density compact on desktop and desktop browsers, standard on phones (`VisualDensity.adaptivePlatformDensity`). Launcher name and browser title: **Clinic**. |
| Build order | Admin setup first, then Reception visit flow, Doctor, Appointments, Inventory, Finance, hardening. |
| Firebase project | `ramzan-clinic-web` (project number 662931473606), created by the owner. Android, iOS, web and Windows apps registered; `lib/firebase_options.dart` generated. Firestore, Auth (Email/Password) and Blaze enabled on 31 Oct 2026. Storage bucket not yet created: it must be created in **us-central1** (no-cost quota), not Mumbai. |
| Cost | Stay inside Blaze no-cost quotas at 500 visits a day, 300 of them new patients (owner figure, 5 Nov 2026; FIREBASE_ARCHITECTURE §11). No photo prescriptions, no managed backup, summaries by increments, no listeners over whole collections. |
| Dev backend | Flutter app talks to the live Firebase project during development. Cloud Functions and rules are developed on the local Emulator Suite, then deployed. |
| Test backend | All integration, rules and functions tests run against the local Firestore Emulator Suite with seed data. Tests never touch the live project. No second Firebase project. |
| Automated tests | Full: unit tests (domain + view models), widget tests (every screen), integration tests (key flows). Firestore rules tests on the emulator. |
| App identifier | `ramzan.shop.ramzan` for Android package and iOS bundle ID. Android minSdk 23, iOS 15.0. |
| Cloud Functions runtime | 2nd gen, TypeScript, Node 22 runtime (local Node 24 is fine for tooling). |
| Test admin (dev only) | Removed in Phase 9 (6 Nov 2026). Previously decided 2 Nov 2026: the login screen shows a **Create test admin** button in debug builds only (`kDebugMode`). It calls `createTestAdmin`, which creates or restores `admin@mytester.com` / `1234567890` as an active admin, then signs in. The function only works while `functions/.env` has `ALLOW_TEST_ADMIN=true`. Phase 9 turns it off and deletes the account. Needs the function deployed (owner) to work against the live project; works on the emulators today. |
| Version control | Git initialised by the owner on 31 Oct 2026, branch `main`. Commit at the end of each phase at least. |
| Phase 4 decisions (4 Nov 2026) | Reception may move visits to in progress and completed (rules opened for `status`, `startedAt`, `completedAt`). Discount reasons are a preset list plus Other with free text (`DiscountReasons`). Shift summary is clinic-wide with a "My visits only" switch. Fee is read-only on the form; a missing fee blocks save. Visits page lists today only; history and reprint live on the patient page. One `TodayVisitsController` holds the today's-visits listener for the list, queue, summary, sync badge and the waiting count. Tokens come from a cache-only query. Receipt PDF is built with `pdf` behind a `ReceiptPrinter` abstraction (`printing` in the app, a fake in tests). Offline is exercised in the Chrome test with `disableNetwork()` / `enableNetwork()` on the Firestore instance. Reception writes go through `commitOrQueue` (wait 1.5 s for the server, then treat as queued) because Firestore only resolves write futures on acknowledgement; applied to the Phase 3 patient writes too. Admin gets the same visit routes under `/admin/visits/...` since Admin may create visits too; `/admin/visits` itself stays a placeholder until Phase 8. |
| Phase 9 decisions (6 Nov 2026) | Audit log: edits and soft deletes only (creates, queue moves, sale stock decrements and a user's own password-flag clear skipped), one `audit*` trigger per audited collection over `auditWriteCore`, entries keyed by the event ID, kept forever (no TTL), before/after of the changed fields only, `userName` read once from `users`. Viewer at `/admin/audit` by day with user, record and action filters on the client. App Check wired behind `RECAPTCHA_SITE_KEY` with debug providers on the emulators and in debug builds; enforcement is the owner's console step. The dev test admin (button, `DevToolsRepository`, `createTestAdmin`, `ALLOW_TEST_ADMIN`) is removed. Release prep in the repo: Hosting cache headers, Android release signing from a git-ignored `android/key.properties` (falls back to the debug key), ProGuard rules, iOS build notes. Test seams agreed with the owner: Functions (`auditWriteCore`: skips, edit, delete, reasons, redelivery), rules (`auditLogs` Admin read only), Dart (`AuditEntry`/`AuditFilter`, repository on fake Firestore, view model and view, `AppCheckConfig`), one Chrome flow (`integration_test/admin_visits_audit_flow_test.dart`). |
| Phase 10 decisions (6 Nov 2026) | Scope chosen by the owner from the deferred items: (1) report PDF per section, built with `pdf` and handed to `ReceiptPrinter` (print dialog), no new package; (2) inventory margins by snapshotting `unitCost` on each sale line, `salesCost` / `salesCostByCategory` on the day summaries, a Sales margins report section; (3) sidebar version footer from `AppVersion.current` in `lib/core/`, guarded by a unit test that reads `pubspec.yaml`; (4) Admin theme colour from a fixed `ThemeColor` palette stored in `settings/general.themeColor`, applied to both themes through `SettingsController`, login screen stays teal. Rules unchanged (settings writes are already Admin-only and unrestricted by key; sale line items are not inspected). Test seams agreed with the owner: `ReportPdf.build`, `ReportsViewModel.exportPdf` over `FakeReceiptPrinter`, `report-export-pdf-<key>`; `SaleLine.unitCost` round trip and snapshot in `NewSaleViewModel`; Functions `saleContribution` and `recomputeDayCore` with costs; `DailySummary` fields and the `salesMargins` table with literal CSV; `AppVersion` vs pubspec; `AppShell` footer; `ThemeColor.parse`; settings model round trip; `AppTheme` seeds and `ClinicApp` rebuild on colour change; settings swatches and save; one Chrome flow `admin_theme_version_flow_test.dart`. |
| Phase 8B decisions (6 Nov 2026) | Payouts in two reversible steps: created unpaid, Mark paid writes the payout expense in the same batch, Mark unpaid (reason) soft-deletes that expense and clears the flag, Delete (reason) only while unpaid; the period defaults to last month; overlapping payouts of the doctor are flagged, not blocked. Reports: nine sections from `dailySummaries` with one CSV per section (`file_saver` behind a `FileSaver` abstraction, `InMemoryFileSaver` in tests); PDF export and inventory margins deferred. Visit corrections: Admin may change the doctor even when a prescription exists (the prescription keeps its doctor); every correction stores `editReason`, rules require it and lock the department; `/admin/visits` reads one day at a time (deleted visits included). Test seams agreed with the owner: domain (`VisitCorrectionRules`, `PayoutRules`, `ReportTables` / `ReportCsv` with literal CSV), repositories on fake Firestore (visit `visitsOn` / `correctVisit` / `deleteVisit`, payout create / mark paid / mark unpaid / delete batches), rules (`payouts`; visit `editReason` and department lock), one Functions test (a doctor change moves the `byDoctor` buckets), view models and views, one Chrome flow (`integration_test/admin_visit_corrections_flow_test.dart`). |
| Phase 8A decisions (6 Nov 2026) | Phase 8 in two owner checkpoints: 8A (`applyDailySummaryDelta` triggers on `visits`, `sales` and `expenses`, the `recomputeDay` repair callable, the Admin dashboard, manual expenses) and 8B (doctor payouts, date-range reports with export, Admin visit edit and soft delete). Dashboard charts use `fl_chart`. Dashboard ranges: Today, This week (from Monday), This month, Custom with no cap on the span (owner's choice; one `dailySummaries` read per day in the range). Revenue = visit net fees + sales total; Discounts = visit discounts + sale discounts; Net profit = revenue − expenses. The Expenses page shows one day at a time (date picker, default today; one `date ==` read, no listener). Manual expenses may be edited (category, amount, date, note) and soft deleted with a reason; purchase and payout expenses may only be soft deleted (the bill or payout stays the record). Decided for 8B now: Admin may change a visit's doctor only within the same department (token label and department buckets stay valid); `/admin/visits` picks a day and filters that day's list by name, number, phone or token on the client. Test seams agreed with the owner: Functions on the emulator (delta core for visit, sale and expense create, edit, soft delete, status-only skip, duplicate event skip; `recomputeDay`), rules for `dailySummaries`, `summaryEvents` and `expenses` updates, Dart domain (`DailySummary` sums, `DashboardRange`, `ExpenseRules`) and repositories on fake Firestore, view models and views, one Chrome flow (`integration_test/admin_summaries_flow_test.dart`). |
| Phase 7B decisions (6 Nov 2026) | Sales: a walk-in sale without a patient record is allowed (customer name typed, `patientId` null). Admin sells from the same Sales page mounted at `/admin/sales` (non-primary destination, under More on phones) and from Sell buttons on the visit and patient pages. Admin can void a sale (soft delete with a reason); the void batch restores stock with a positive `sale` movement per line. Receipt: a sale prints its own receipt from the sale page right after saving; when the sale is linked to a visit, the visit receipt also lists the items sold (the sale is found by `visitId`, the visit document is not written, so `visits.saleId` stays unused). Lens lines are lens type + power + quantity with no eye tag; the picker offers Add right / Add left from the patient's latest eye prescription (latest 3 visits read once, first prescription with eye values). Today's sales are one `date ==` listener held by the Sales page while it is open (sorted and `deleted`-filtered on the client); the sale of a visit is a `visitId ==` read; no `sales` index. Line prices default to the item's sale price and can be edited; short stock warns on the line and in the save confirmation. Test seams agreed with the owner: domain (`SaleRules`, `LensSuggestion`), `SalesRepositoryImpl` on fake Firestore (sale batch with stock decrements and movements, today's listener, sale by visit, void batch), `sales` rules on the emulator (Reception and Admin create, Admin void only, no delete), view models and views (sales list, new sale with item and lens pickers, sale detail with print and void, visit receipt items), one Chrome flow (`integration_test/reception_sales_flow_test.dart`). |
| Phase 7A decisions (6 Nov 2026) | Phase 7 in two owner checkpoints: 7A (Admin inventory: items by category, lens grid, suppliers, purchase bills that create an expense, manual adjustments, movement history, low-stock filter) and 7B (Reception and Admin sales with the lens power picker, receipt, stock deduction, today's sales). Lens grid range SPH −20.00 to +20.00 and CYL 0.00 to −8.00 in 0.25 steps; one `inventoryItems` document per type and power, created on first use with the document ID equal to `lensKey`. Short stock on a sale warns but does not block (7B). Items are held by one `InventoryController` listener for reception and admin sessions (FIREBASE_ARCHITECTURE §9); the lens grid, low-stock filter and item search are client-side over it. Purchases are immutable (no edit screen, no update rule). Movement history shows the last 50 movements of an item. Test seams agreed with the owner: domain (`InventoryRules`, `LensPower`/`LensGrid`, `PurchaseRules`), `InventoryRepositoryImpl` on fake Firestore (item create with opening stock, update, adjustment batch, purchase batch with movements, increments and the expense, lens grid listener, suppliers), rules for `inventoryItems` (Admin; Reception `stock` increment only), `suppliers`, `purchases`, `expenses` (Admin) and `stockMovements` (create only) on the emulator, view models and views for the six inventory tabs, item form, item detail with adjust dialog, supplier dialog and purchase form, and one Chrome flow (`integration_test/admin_inventory_flow_test.dart`). |
| Phase 6B decisions (6 Nov 2026) | Reminders: tomorrow = booked manual + surgery-day; follow-up and post-op due = today..today+N; Overdue = last 7 days; sent rows stay marked with Send again; hidden sections for switched-off types. One range read, no listener; Send opens `wa.me` through an injected opener and writes `reminderSentAt`/`reminderSentBy`. Doctor page `/doctor/appointments`: next 30 days, one read + Refresh, under More on phones (index `doctorId, date`). Reception "Change post-op days" from post-op rows (day view and patient tab) through a sheet that calls `OperationsRepository.reschedule(postOpDays:)`; a days-only reschedule keeps the surgery appointment. Code: `ReminderRules`/`ReminderMessage` in `features/appointments/domain/`, `remindersWindow`, `markReminderSent`, `doctorUpcoming` on the repository, `RemindersViewModel`/`RemindersView`, `DoctorAppointmentsViewModel`/`DoctorAppointmentsView`, `PostOpDaysSheet` in `features/operations/`. Seams agreed with the owner: domain, repository + rules, view models and widgets (Send with an injected opener), one Chrome flow. |
| Phase 6A decisions (5 Nov 2026) | Phase 6 in two owner checkpoints: 6A (booking, day view, Arrived → visit, patient tab) and 6B (reminders, doctor's upcoming list, reception post-op days). Arrived opens the new-visit form (`?patientId=&appointmentId=&doctorId=`) and the visit batch marks the appointment arrived with `visitId`; `Visit.appointmentId` is stored. Day view = date picker plus one column per doctor with appointments that day (queue-board layout). Follow-up and post-op rows can be rescheduled, cancelled and marked no-show; the surgery-day row only Arrived / No-show. Book from the patient search row and the patient page tab; the day view's Book button opens search; the date defaults to tomorrow. Code: `features/appointments/` (`AppointmentRules`, `AppointmentsRepository`, day / book / patient-tab view models and views), `VisitInput.appointmentId`, `NewVisitViewModel.initialDoctorId`. Test seams agreed with the owner: domain rules, repository on fake Firestore plus rules on the emulator, view models and widgets per screen, one Chrome flow. |
| Phase 5B decisions (5 Nov 2026) | Surgery day is booked as a `source: operation` appointment next to the post-op ones; the surgeon is any active doctor of the department (self preselected); the new-visit form links a token to the patient's scheduled operation of that type (`visits.operationId`) and shows the date; reception and Admin soft-delete reports with a reason; uploads start from the patient page's Reports tab (title, file or camera, optional visit); Mark done needs every item ticked or an override reason. Code: `features/reports/` (entity, `ReportFiles` checks, repository over `FileStore` + `ImageShrinker`, upload dialog, Reports tab), `features/operations/` (entity, `OperationRules`/`PostOp`, repository, schedule sheet, list, detail), Me-tab defaults editor in `features/visits/` reusing the catalog's checklist and post-op editing logic. Pickers (`file_picker`, `image_picker`) and the shrinker sit behind typedefs/interfaces so widget tests inject bytes. Seams agreed with the owner: domain, repositories + rules (Firestore and Storage) on the emulator, view models and widgets, one Chrome flow for operations (the browser file dialog cannot be driven, so upload is covered at the repository and widget seams). |
| Phase 5 decisions (5 Nov 2026) | Delivered in two owner checkpoints: 5A (queue, consultation, prescriptions + PDF, history, personal summary) and 5B (reports, operations, operation-type defaults). Follow-up dates write `appointments` documents at once (Phase 6 adds the screens). Save and Complete are separate; Complete without a prescription confirms first. The assigned doctor edits a prescription until the end of its Karachi day (rules compute the cut-off from `date`). Follow-up date via quick chips plus a picker. Me tab: completed-visit counts and own gross/discount/net for today, week (from Monday) and month through aggregate queries (`count` + `sum`, one read per period, needs the `doctorId, status, deleted, date` index). `TodayVisitsController` also serves doctor-only sessions with a doctor-scoped query. Code lives in `features/prescriptions/` (entity, rules, repository, consultation, PDF), the doctor queue and summary in `features/visits/`, the doctor history page in `features/patients/`; the appointment write is a model in `features/appointments/data/`. Test seams agreed with the owner: domain (Rx validation, summary periods, follow-up dates), repositories on fake Firestore plus rules on the emulator, view models and widgets per screen, one Chrome flow. |
| Patient cache decisions (5 Nov 2026) | Cost review for 500 visits a day found the full `patients`/`families` listeners and server-side searches were the two largest read costs (FIREBASE_ARCHITECTURE §11). Replaced by local-first search plus delta sync (FIREBASE_ARCHITECTURE §1, §9): `PatientsRepository` searches take a `ReadSource` (`core/read_source.dart`), `PatientSearchViewModel` asks the cache first and the server on a miss and exposes `origin` and `searchOnline()`, `PatientSyncController` (replacing `PatientCacheController`) pulls `updatedAt >= watermark` pages at sign-in and every 5 minutes with the watermark in `KeyValueStore`, the two patient Functions stamp `updatedAt`, web persistence is multi-tab with index auto-creation and `navigator.storage.persist()`. Test seams: repository delta queries and read sources on fake Firestore, the sync controller with a mock repository and `InMemoryKeyValueStore`, the search view model local-first paths with mocks, the Search online footer as a widget test, the `updatedAt` stamps in the Functions tests, and the existing Chrome flows (searches of seeded patients now exercise the cache-miss path). Status 5 Nov 2026: 440 Flutter unit + widget tests, 149 Functions/rules tests, 13 integration flows in six files, all green headless on Chrome. Awaiting the owner's screen review of the search footer and a Functions deploy (owner: `firebase deploy --only functions`). |
| Paged history decisions (5 Nov 2026) | Owner decision: the doctor's History tab loads the past 3 visits when opened and a "Load more" button adds 3 more, instead of subscribing to the whole history on every consultation (FIREBASE_ARCHITECTURE §11). Code: `VisitsRepository.patientVisitsPage` (one-shot, `createdAtLocal desc`, document cursor exposed as the last visit id; new composite index `patientId, deleted, createdAtLocal`), `PrescriptionsRepository.getPrescriptions` (one read per visit with `hasPrescription`), `PatientHistoryViewModel` in `features/visits/` with `load()` / `loadMore()`, `PatientHistoryLoader` that starts the first page when the tab is built, `VisitHistoryList` and the reception Visits tab with a `LoadMoreRow`. `watchPatientVisits` and `watchPatientPrescriptions` were removed; `ConsultationViewModel` and `PatientDetailViewModel` no longer hold history. Tab labels show `patient.visitCount`. Test seams: the page query and batch get on fake Firestore, the view model with mocks, the History tab and Load more as widget tests on the consultation screen, the doctor history page and the reception patient page, plus the existing Chrome flows. |
| Phase 2 decisions (3 Nov 2026) | Doctor ↔ login link is kept by `createUser` / `setUserRoles` (one login per doctor; the user form has a doctor picker, the doctor form shows the link read-only). First run: banner on Admin pages plus `/admin/setup`, no forced redirect. Department code editable with a warning; doctors' `departmentCode` is rewritten in the same batch. Logo upload goes through a `FileStore` abstraction (`core/storage/file_store.dart`) so tests use an in-memory store. Catalog screens share loading state through the `CatalogData` mixin; each list screen has a dialog (departments) or a full page with `PageHeader` (doctors, visit types). |

---

## 2. Toolchain (verified 31 Oct 2026)

| Tool | Version |
|---|---|
| Flutter | 3.47.9 stable, Dart 3.13.7 |
| Node | 24.7.0, npm 11.18 |
| Firebase CLI | 15.24.0 |
| FlutterFire CLI | 1.4.0 |
| Java | 21 (needed by the Firestore emulator) |

---

## 3. Firebase Project Setup (owner steps)

Do these in the Firebase console, then share the project ID.

1. **Create project** at console.firebase.google.com. Any name, for example `clinic-app`. Google Analytics is optional.
2. **Upgrade to Blaze** (Settings → Usage and billing). Attach a billing account. Functions 2nd gen and scheduled backups need it.
3. **Firestore**: Build → Firestore Database → Create database → location `asia-south1` → production mode.
4. **Authentication**: Build → Authentication → Get started → enable **Email/Password**.
5. **Storage**: Build → Storage → Get started → location **`us-central1`** (the no-cost quota applies only to US buckets) → production mode. Still to do as of 31 Oct 2026.
6. Share the **project ID** (Project settings → General).

Then on this machine:

```sh
! firebase login            # interactive, run with the ! prefix
flutterfire configure --project=<project-id> --platforms=web,android,ios \
  --android-package-name=ramzan.shop.ramzan --ios-bundle-id=ramzan.shop.ramzan
firebase init firestore functions storage emulators hosting   # done by hand on 31 Oct 2026, see Phase 0
```

App Check is enabled last (Phase 9) so it does not block development.

---

## 4. Folder Layout

```
lib/
  main.dart                     # Firebase init, Provider tree, runApp
  app.dart                      # MaterialApp.router, theme
  core/
    firebase/                   # firebase_options.dart (generated), instances
    theme/                      # ColorScheme, typography, department accents
    routing/                    # go_router config, role guards
    widgets/                    # shared widgets (money text, date picker, empty state, confirm dialog)
    utils/                      # karachi_date.dart, money.dart, search_keys.dart, phone.dart
    errors/                     # Failure types, error mapping
    storage/                    # key_value_store.dart (preferences), file_store.dart (Cloud Storage uploads)
  features/
    auth/                       # login, mustChangePassword, current user + roles
    settings/                   # settings/general, logo upload, first-run setup, SettingsController
    users/                      # Admin: user list, create, roles, doctor picker (calls createUser/setUserRoles)
    catalog/                    # departments, doctors (fees, salary, share), visitTypes, fee grid
    patients/                   # families, patients, registration, search, temp IDs
    visits/                     # visit creation, tokens, discount, payment, queue, receipt PDF
    appointments/               # appointments, due-today list, WhatsApp link
    prescriptions/              # typed + photo prescriptions, follow-up date
    reports/                    # report upload and viewing
    operations/                 # operation record, checklist, post-op appointments
    inventory/                  # items (incl. lens grid), suppliers, purchases, stock movements, sales
    finance/                    # expenses, payouts
    analytics/                  # dailySummaries dashboard, date-range reports, export
    audit/                      # Admin audit log viewer
functions/                      # TypeScript Cloud Functions (see FIREBASE_ARCHITECTURE §5)
  src/
    index.ts
    users.ts  patients.ts  summaries.ts  audit.ts  families.ts
  test/
firestore.rules
firestore.indexes.json
storage.rules
firebase.json
test/                           # unit + widget tests, mirrors lib/features
integration_test/               # end-to-end flows
```

Each feature folder:

```
features/visits/
  domain/
    entities/visit.dart
    repositories/visit_repository.dart        # abstract
    usecases/create_visit.dart ...            # pure logic, unit-tested
  data/
    models/visit_model.dart                   # fromMap/toMap, extends entity
    repositories/visit_repository_impl.dart   # Firestore
    datasources/visit_firestore_source.dart
  presentation/
    viewmodels/visit_form_vm.dart             # ChangeNotifier
    screens/
    widgets/
```

---

## 5. Packages

Runtime:

| Package | Purpose |
|---|---|
| `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_app_check` | Firebase |
| `provider` | State management |
| `go_router` | Routing |
| `intl` | Date and PKR formatting |
| `pdf`, `printing` | A4 receipt and prescription PDF, print dialog on web |
| `url_launcher` | `wa.me` WhatsApp links |
| `image_picker`, `flutter_image_compress` | Report photos captured by camera, resize to 1200 px / quality 80 |
| `file_picker` | Report uploads on web and mobile |
| `file_saver` | CSV report downloads on web and mobile (Phase 8B), behind `core/storage/file_saver.dart` |
| `cached_network_image` | Report and photo display |
| `shared_preferences` | Per-device preferences (last department filter, etc.) |
| `uuid` | Temp patient IDs and client-generated document IDs |

Development:

| Package | Purpose |
|---|---|
| `flutter_lints` | Lints |
| `mocktail` | Mocks for repositories in unit and widget tests |
| `fake_cloud_firestore`, `firebase_auth_mocks` | In-memory Firestore and Auth for data-layer tests |
| `integration_test` | End-to-end tests |
| `@firebase/rules-unit-testing` (functions/) | Security rules tests on the emulator |

---

## 6. Build Phases

Each phase ends with: screens reviewed by the owner, unit + widget tests passing, integration test for the phase's main flow, rules updated and tested, functions deployed if changed. Phases map to feature folders above.

### Phase 0 — Project setup
Status 31 Oct 2026: Firebase init done by hand (same files `firebase init` writes): `.firebaserc`, `firebase.json` (firestore, storage, functions, hosting, emulators), deny-all `firestore.rules` and `storage.rules`, empty `firestore.indexes.json`, `functions/` TypeScript scaffold (firebase-functions 7, firebase-admin 13, Jest + ts-jest, rules-unit-testing). Emulator ports: Auth 9099, Firestore 8080, Functions 5001, Storage 9199, Hosting 5000, UI 4000. First rules deploy is run by the owner (`firebase deploy --only firestore:rules,storage`).

- Rename app ID to `ramzan.shop.ramzan`, app name "Clinic".
- Add packages, `flutterfire configure`, `firebase init`.
- `core/`: theme, router skeleton, Firebase instances, Karachi date utils, money utils, search-key builder (unit-tested).
- `functions/` TypeScript scaffold, emulator config, empty rules that deny everything.
- Enable Firestore offline persistence on web (`persistentLocalCache`).

### Phase 1 — Auth and users
Status 3 Nov 2026: built and verified on Chrome: 121 Flutter unit + widget tests (also run with `--platform chrome`), 79 Functions/rules tests, 5 integration flows green via `tool/integration_test_web.sh` (wrong password, admin creates a user and signs out, forced first-login password change and change by choice, dev test-admin button, role switch). Integration testing found and fixed three app bugs: forced password change never left the screen, a user-document update dropped pushed pages (session now notifies only on visible change), and the user form notified a disposed view model. Remaining before Phase 1 is called done: owner screen review and the first Functions + rules deploy (owner).

- Login screen, forced password change, role-based landing (Reception / Doctor / Admin shells with sidebar, rail or bottom bar by width; role switcher for multi-role users).
- Functions: `createUser`, `setUserRoles`, `resetUserPassword` (custom claims).
- Admin: user list (search, role filter, show inactive), create user, edit name and roles, deactivate and reactivate, reset password.
- Rules: `users` collection, role helpers.
- Local emulator run: `--dart-define=USE_EMULATORS=true` points the app at Auth 9099, Firestore 8080, Functions 5001. `node functions/scripts/seed-emulator.js` seeds four accounts (admin, first-login reception, plain reception, multi-role) plus the catalog and one family. Integration test runs on Chrome via `tool/integration_test_web.sh` (ChromeDriver + emulators + `flutter drive`); see the header of `integration_test/login_flow_test.dart`. Decided 2 Nov 2026: integration tests run on web first (the reception platform); the macOS desktop target is not used.
- Deferred to Phase 2: the doctor picker in the user form is a text field for the doctor record ID until the doctors collection exists.
- Dev helper: debug-only **Create test admin** button on the login screen (`createTestAdmin` callable, see §1).

### Phase 2 — Admin master data
Status 3 Nov 2026: built. 192 Flutter unit + widget tests, 90 Functions/rules tests, and a second Chrome integration file (`integration_test/admin_setup_flow_test.dart`: first-run setup and settings save; department, doctor, fee grid row save, doctor login through the picker, link shown on the doctor form). Remaining before Phase 2 is called done: owner screen review, and a Functions + rules + storage rules deploy (owner). Note: the live Storage bucket (§3 step 5) is still to be created; the logo upload works on the emulator today.

- Settings: clinic name, logo, address, phone, receipt footer, default receipt copies, follow-up reminder days, WhatsApp reminder toggles and templates with placeholders.
- Departments (name, code), doctors (department, specialisation, salary, share %, share basis, fee row), visit types (operation flag, follow-up flag, default checklist, post-op days), fee grid per department with Save row.
- First-run setup page (`/admin/setup`) reached from a banner; creates branch, settings, two departments and five visit types. Emulator seed extended with the same catalog and a doctor linked to the multi-role account.
- User form: the doctor record ID text field became a picker of unlinked active doctors; `createUser` / `setUserRoles` maintain `doctors.userId`.
- Rules for `branches`, `settings`, `departments`, `visitTypes`, `doctors`; Storage rule for `clinic/logo.png`.
- Integration helpers moved to `integration_test/support.dart`; `tool/integration_test_web.sh` now runs every `integration_test/*_test.dart` in name order inside one emulator session (with the Storage emulator).

### Phase 3 — Patients and families
Status 4 Nov 2026: built test-first (repository on fake Firestore, view models and widgets with mocks, triggers and rules on the emulator, one Chrome flow): 241 Flutter unit + widget tests, 107 Functions/rules tests, 9 integration flows in three files, all green headless on Chrome. Remaining before Phase 3 is called done: owner screen review and a Functions + rules deploy (owner).

- Family lookup by phone, create family, add patient, move patient between families, change family phone (blocked online when another family has the number; `checkDuplicateFamilyPhone` flags offline clashes).
- Patient search by phone (family or personal), patient number, temp number and name prefix, grouped by family. Local-first since 5 Nov 2026: the cache answers first, the server only on a miss; `PatientSyncController` keeps the cache fresh with delta pulls for reception sessions (FIREBASE_ARCHITECTURE §9). Offline, patients this device has seen are searchable; others are not.
- Temp IDs (`T-XXXXX`) on the client; `assignPatientNo` trigger with a counter per Karachi year, idempotent on retried events.
- Age entered as years is stored as an approximate date of birth (decided 4 Nov 2026, FEATURES §2).
- Patient page (`/reception/patients/:id`, also under `/admin/patients`): header, family card with Add member / Edit family / Change phone / Move, Edit, WhatsApp link from the ad-hoc template; Visits, Reports and Appointments tabs are placeholders until Phases 4–6. The Doctor's history view (`/doctor/patients/:id`) arrives in Phase 5 on the same `PatientHeader`.
- Rules for `families`, `patients` (functions-only fields locked) and `counters` (nobody). Seed adds `reception@clinic.test` and the Khan family.
- Tests: `integration_test/reception_patients_flow_test.dart` (register family and patient, number assigned by the trigger, add member, change phone, move patient, search by phone and name).

### Phase 4 — Reception visit flow
Status 5 Nov 2026: built test-first (seams agreed with the owner: domain pricing/token/receipt, `VisitsRepositoryImpl` on fake Firestore, view models and views, rules on the emulator plus a Chrome flow with offline): 311 Flutter unit + widget tests, 117 Functions/rules tests, 11 integration flows in four files, all green headless on Chrome (`integration_test/reception_visit_flow_test.dart`: walk-in visit with discount and JazzCash → token dialog → detail → patient tab → queue Start/Complete → summary; offline visit with `disableNetwork()` → next token → badge Syncing 1 → Online after reconnect). Remaining before Phase 4 is called done: owner screen review and a rules deploy (owner: `firebase deploy --only firestore:rules`). Found while testing: Firestore write futures never resolve offline, so repositories now use `commitOrQueue` (also applied to the Phase 3 patient writes).

- New visit (`/reception/visits/new?patientId=`): patient → department → doctor (with "waiting now") → visit type → fee auto (read-only) → discount amount or percent + preset reason or Other → payment method with optional reference → copies → Save / Save and print → token dialog with receipt preview.
- Receipt PDF (A4, one page per copy) built on the client with `pdf`, printed through `printing`; reprint from the visit detail page and the patient page's Visits tab.
- Today's visits list, queue board (one column per doctor with visits today, toggle to show all active doctors) with Start / Complete actions, status chips.
- Shift summary screen: visits, cash, per-method totals, discounts; "My visits only" switch.
- `SyncBadge` in the top bar (Online / Offline / Syncing N) driven by the today's-visits listener (resolves §9 open point 3).
- Patient page Visits tab and the search row's New visit button go live.
- Rules for `visits`; rules tests; `integration_test/reception_visit_flow_test.dart` including an offline visit (network disabled, token still issued, badge shows pending, syncs on reconnect).

### Phase 5 — Doctor
Delivered in two checkpoints (decided 5 Nov 2026), each ending with an owner screen review.

**5A — queue, consultation, prescriptions, history, summary.** Status 5 Nov 2026: built test-first at the seams agreed with the owner (domain: `EyeFields`, `PrescriptionRules`, `FollowUp`, `DoctorPeriods`; data: `PrescriptionsRepositoryImpl` and the doctor queries of `VisitsRepositoryImpl` on fake Firestore; rules for `prescriptions` and `appointments` on the emulator; view models and views for queue, consultation, history, Me; one Chrome flow): 376 Flutter unit + widget tests, 129 Functions/rules tests, 12 integration flows in five files, all green headless on Chrome (`integration_test/doctor_flow_test.dart`: reception issues a token → multi-role user switches to Doctor → queue → consultation starts the visit → Eye prescription with a one-week follow-up → Save → Complete → Done today → Me totals → read-only patient search → history shows the prescription). Remaining before 5A is called done: owner screen review and a deploy of rules and the new index (owner: `firebase deploy --only firestore:rules,firestore:indexes`). Note: `patients.test.ts` "falls back to now" is timing-dependent when the owner's Functions emulator is live (the trigger numbers the patient first); it passed on the rerun and always passes under the project's own `npm test`.
- Doctor queue (`/doctor/queue`): own visits today from `TodayVisitsController` (doctor-scoped listener for doctor-only sessions); in progress first, waiting in token order, Done today collapsed; Start / Complete from the row; tap opens the consultation and starts the visit.
- Consultation (`/doctor/visits/:id`): patient header with token, type and fee / discount / net; Prescription tab (Eye table, Homeo rows, or diagnosis and advice only for other departments), History tab (patient's past visits with their prescriptions), Reports and Operation tabs as 5B placeholders; follow-up chips and picker; bottom bar Save, Print Rx, Complete. Prescription locked after its Karachi day.
- Prescription PDF (A4, clinic header, doctor and specialisation, patient block, Eye table or Homeo rows, diagnosis, advice, follow-up, signature line) through the existing `ReceiptPrinter`.
- Doctor patient search (`/doctor/patients`, read-only) and history page (`/doctor/patients/:id`): `PatientHeader`, visits newest first, each expandable to its prescription.
- Me (`/doctor/me`): today / this week / this month tiles with completed visits, gross, discounts, net from aggregate queries.
- Rules for `prescriptions` and `appointments`; `firestore.indexes.json` gets the summary index; rules tests; `integration_test/doctor_flow_test.dart` (reception issues a token, doctor starts the visit, types an Eye prescription, saves, sets a follow-up, completes; Me shows the count; history shows the prescription).

**5B — reports, operations, defaults.** Status 5 Nov 2026: built test-first at the agreed seams (domain: `ReportFiles`, `OperationRules`, `PostOp`; data: `ReportsRepositoryImpl` over `InMemoryFileStore` + a fake shrinker, `OperationsRepositoryImpl` and the catalog defaults update on fake Firestore; Firestore rules for `reports`, `operations`, doctor edits of `visitTypes`, `appointments` source `operation`, and `storage.rules` in `functions/test/storage.test.ts`; view models and widgets for the Reports tab and dialogs, schedule sheet, operations list and detail, defaults editor, new-visit link; one Chrome flow): 428 Flutter unit + widget tests, 143 Functions/rules tests, 13 integration flows in six files, all green headless on Chrome (`integration_test/doctor_operations_flow_test.dart`: reception checkup token → doctor schedules Cataract Surgery from the Operation tab → reception issues the surgery-day token and sees the link → doctor ticks an item, adds post-op day 14 with confirm, marks done with an override reason → Done tab). Found while testing: the detail page's action buttons were at the end of a long scroll and unreachable, so they moved to a fixed bottom bar. Remaining before 5B (and Phase 5) is called done: owner screen review and a deploy of rules, Storage rules and the index (owner: `firebase deploy --only firestore:rules,firestore:indexes,storage`).
- Reports: upload dialog on the patient page's Reports tab (title, file or camera, optional visit), client resize for images, Storage rule for `patients/{id}/reports/*`, `reports` rules, list with open-in-new-tab and soft delete with reason; Reports tab on the doctor's consultation and history page.
- Operations: schedule from the consultation's Operation tab (type, surgeon, date, notes) writing the operation plus surgery-day and post-op appointments in one batch; `/doctor/operations` (Scheduled / Done) and `/doctor/operations/:id` (checklist with who and when, add item, post-op day chips with confirm and regeneration, date change, Mark done or Override with reason, Cancel with reason); the consultation Operation tab shows the linked or scheduled operation.
- New-visit form links an operation visit type to the patient's scheduled operation and shows the date.
- Me tab: defaults editor for the doctor's department operation types (`visitTypes` rule opened for those two fields).
- Rules tests for `reports`, `operations`, `visitTypes` doctor edits, `storage.rules`; `integration_test/doctor_operations_flow_test.dart`.

### Phase 6 — Appointments and reminders
Two owner checkpoints (decided 5 Nov 2026).

**6A — booking, day view, Arrived.** Status 5 Nov 2026: built test-first at the seams agreed with the owner (domain: `AppointmentRules`; data: `AppointmentsRepositoryImpl` and the `createVisit` Arrived batch on fake Firestore; rules for `arrived` and the reception changes on the emulator; view models and views for the day view, booking form and patient tab; one Chrome flow): 482 Flutter unit + widget tests, 151 Functions/rules tests, 15 integration flows in seven files, all green headless on Chrome (`integration_test/reception_appointments_flow_test.dart`: search → Book for tomorrow → patient tab lists it → day view → Arrived → new-visit form with the doctor preselected → token → row shows Arrived; second booking rescheduled and cancelled from the day view). Remaining before 6A is called done: owner screen review and a deploy of the rules (owner: `firebase deploy --only firestore:rules`).
- `features/appointments/`: `AppointmentRules` (booking validation, allowed row actions by source, status and day), `AppointmentsRepository` (book, reschedule, cancel, no-show, watch a day, watch a patient's appointments), `AppointmentsDayViewModel`, `BookAppointmentViewModel`, `PatientAppointmentsViewModel`; `/reception/appointments` and `/admin/appointments` (day view), `/<role>/appointments/new?patientId=` (book form), the patient page Appointments tab, Book enabled on search rows.
- Arrived: `/<role>/visits/new?patientId=&appointmentId=&doctorId=`; `VisitInput.appointmentId`; `createVisit` marks the appointment arrived in its batch; `visits.appointmentId` stored.
- Rules: `appointments` with `status == arrived` need `visitId`; rules tests; `integration_test/reception_appointments_flow_test.dart` (search → Book → day view → Arrived → token → patient tab).

**6B — reminders, doctor list, post-op days.** Status 6 Nov 2026: built test-first at the seams agreed with the owner (domain: `ReminderRules`, `ReminderMessage`; data: `remindersWindow`, `markReminderSent`, `doctorUpcoming` and the days-only `OperationsRepository.reschedule` on fake Firestore; rules for `reminderSentAt` by reception on the emulator; view models and views for reminders, the doctor page and the post-op days sheet with an injected opener for Send; one Chrome flow): 508 Flutter unit + widget tests, 152 Functions/rules tests, 17 integration flows in eight files, all green headless on Chrome (`integration_test/reception_reminders_flow_test.dart`: reception books Ali for tomorrow → Reminders lists it and Sara's surgery day under Appointments tomorrow → day view two days ahead → post-op row opens the sheet → day 21 added, saved after confirm, re-opened with the saved days; the multi-role user switches to Doctor and sees the rows on the upcoming page). Found while testing: post-op days must stay editable after the operation is done (follow-ups continue after surgery), so only a cancelled operation locks the sheet; the sheet gained a Close button because a modal sheet on desktop web has no obvious way out. Remaining before 6B (and Phase 6) is called done: owner screen review and a deploy of the rules and the new index (owner: `firebase deploy --only firestore:rules,firestore:indexes`).
- `/reception/reminders`: Appointments tomorrow, Follow-ups due, Post-op follow-ups due, Overdue (one range read; `ReminderRules.sections`); Send opens `wa.me` with the type's template filled (`ReminderMessage.fill`) and marks the row sent; sent rows stay with the time and Send again; sections for types Admin switched off are hidden.
- `/doctor/appointments`: the doctor's booked appointments for the next 30 days grouped by day, read once with Refresh; a More entry on phones.
- "Change post-op days" on post-op rows (day view, patient tab) for reception and Admin: `PostOpDaysSheet` over `OperationsRepository.reschedule(postOpDays:)`, which now keeps the surgery appointment when only the days change.
- Index `appointments(doctorId, date)`; rules tests for `reminderSentAt` by reception; `integration_test/reception_reminders_flow_test.dart`.

### Phase 7 — Inventory and sales
Two owner checkpoints (decided 6 Nov 2026).

**7A — Admin inventory.** Status 6 Nov 2026: built test-first at the seams agreed with the owner (domain: `LensPower`/`LensGrid`, `InventoryRules`, `PurchaseRules`; data: `InventoryRepositoryImpl` on fake Firestore, item create with opening stock, update, adjustment batch, purchase batch with movements, increments and the expense, lens key as document ID, suppliers, recent purchases; rules for `inventoryItems`, `stockMovements`, `suppliers`, `purchases`, `expenses` on the emulator; `InventoryController`, six view models, the tab strip, category list, lens grid, item form, item detail with adjust dialog, suppliers dialog, purchase form with confirm and bill page as widget tests; one Chrome flow): 599 Flutter unit + widget tests, 167 Functions/rules tests, 18 integration flows in nine files, all green headless on Chrome (`integration_test/admin_inventory_flow_test.dart`: Admin adds Arnica 30 with 12 opening stock → adds single-vision −1.25 / −0.50 from an empty grid cell → adds a supplier → records bill 771 (10 × Rs 90) → the expense exists with Rs 900 → stock reads 22 → adjusts −2 with a reason → movements show the bill, the adjustment and the opening stock). Found while testing: a confirm dialog opened from a page inside the role shell must pop with the dialog builder's context, because the page sits in the `ShellRoute`'s nested navigator and `Navigator.of(pageContext).pop()` popped the page instead (fixed in the new dialogs and in the four older deactivate dialogs of departments, doctors, visit types and users); and the shell's snackbar covers a tab's FAB for four seconds, so the flow waits for it to clear (`waitForGone`) before the next FAB tap. `integration_test/support.dart` gained `reportingFlutterErrors`, which puts Flutter error details into the failure message (the web driver only reports their count). Remaining before 7A is called done: owner screen review and a deploy of the rules and the new index (owner: `firebase deploy --only firestore:rules,firestore:indexes`).
- `features/inventory/`: `ItemCategory`, `LensType`, `LensPower` (format, `lensKey`), `LensGrid` (range and steps), `InventoryItem`, `Supplier`, `Purchase` + `PurchaseLine`, `StockMovement`; `InventoryRules` (item and adjustment validation, low stock, search), `PurchaseRules` (line validation, totals); `InventoryRepository` (`watchItems`, `createItem` with opening stock, `updateItem`, `adjustStock`, `recentMovements`, `watchSuppliers`, `createSupplier`, `updateSupplier`, `createPurchase`, `recentPurchases`, `getPurchase`); `features/finance/` holds the `Expense` entity and model the purchase batch writes.
- `InventoryController` in `main.dart`: the one `inventoryItems` listener for reception and admin sessions.
- `/admin/inventory` → `/admin/inventory/medicine`; tabs medicine, frame, lens (grid), consumable, suppliers, purchases; `/admin/inventory/items/new`, `/admin/inventory/items/:id`, `/admin/inventory/items/:id/edit`, `/admin/inventory/purchases/new`, `/admin/inventory/purchases/:id`.
- Rules for `inventoryItems`, `suppliers`, `purchases`, `expenses`, `stockMovements`; index `stockMovements(itemId, createdAt desc)`; rules tests; `integration_test/admin_inventory_flow_test.dart`.

**7B — sales.** Built 6 Nov 2026 (decisions in §1); awaiting the owner's screen review. Tests: 655 Flutter tests in all after 7B (56 in `test/features/sales/` (rules, lens suggestion, model, repository on fake Firestore, view models, views incl. the visit detail items card), 172 Functions and rules tests in all (6 for `sales`), and `integration_test/reception_sales_flow_test.dart` (visit → sell items with a lens from the grid → stock down → items on the visit page → walk-in sale with short stock → Admin void → stock back). Reception and Admin sales with the lens power picker (pre-selected from the patient's latest eye prescription), discount with reason, payment method, receipt (standalone, and on the visit receipt when linked), stock deduction in the sale batch, today's sales list at `/reception/sales` and `/admin/sales`, Admin void. Short stock warns but does not block (owner decision 6 Nov 2026).

- `features/sales/`: `Sale`/`SaleLine`, `SaleRules` (lines, totals, discount reason, short-stock warnings, void reason), `LensSuggestion` (eye prescription → on-grid `LensPower` per eye), `SalesRepository` (`createSale`, `watchDay`, `saleForVisit`, `watchSale`, `voidSale`), `SalesRepositoryImpl` (sale batch: sale document, `stock` decrement and a `sale` movement per line; void batch: soft delete, `stock` increment and a positive `sale` movement per line).
- Screens: Sales list (`/<role>/sales`), New sale (`/<role>/sales/new?patientId=&visitId=`) with the item picker and the lens picker sheet, Sale detail (`/<role>/sales/:id`) with receipt print and Admin void; Sell buttons on the patient search row, patient page and visit detail; the visit receipt gains an items table when a sale is linked.
- Rules for `sales`; rules tests; `integration_test/reception_sales_flow_test.dart`; seed gains three stocked items.

### Phase 8 — Finance and analytics
Two owner checkpoints (decided 6 Nov 2026; decisions in §1).

**8A — summaries, dashboard, expenses.** Built 6 Nov 2026 test-first at the seams agreed with the owner (decisions in §1); awaiting the owner's screen review and the first deploy of the Functions (the three summary triggers and `recomputeDay`) and rules. Tests: 702 Flutter tests in all after 8A (28 in `test/features/analytics/`: summary sum, ranges, model, repository on fake Firestore, dashboard view model and view; 19 in `test/features/finance/`: expense rules, repository, view models, list and form views), 187 Functions and rules tests in all (11 in `functions/test/summaries.test.ts`; 4 new rules tests for `expenses` corrections, `dailySummaries` and `summaryEvents`), and `integration_test/admin_summaries_flow_test.dart` (Admin records rent → the Expenses tile moves → edits it → a visit for Ali → Revenue, Visits and Net profit move → deletes the expense with a reason → Recompute day changes nothing). Note: the dashboard sums `dailySummaries` only; until the Functions are deployed to the live project the live dashboard stays at zero while visits and sales are recorded, and Recompute day fills a day in afterwards.
- Functions (`functions/src/summaries.ts`): `applyDailySummaryDelta` as one `onDocumentWritten` export per collection (`applyVisitSummaryDelta`, `applySaleSummaryDelta`, `applyExpenseSummaryDelta`) sharing `applyDailySummaryDeltaCore` (before/after contribution, zero delta skipped, `summaryEvents/{eventId}` ledger with a 2-day `expiresAt`, `FieldValue.increment` on every field); `recomputeDay` callable (Admin) rewrites one day's summary from its visits, sales and expenses.
- `features/analytics/`: `DailySummary` (+ `sum`), `DashboardRange` (today, this week from Monday, this month, custom), `SummariesRepository.getRange` (one range query over `dailySummaries`), `recomputeDay` through `FirebaseFunctions`, `DashboardViewModel` + `DashboardView` at `/admin/dashboard` (KPI tiles, `fl_chart` breakdowns, visits per day, low-stock card from `InventoryController`, Recompute day dialog).
- `features/finance/`: `ExpenseRules`, `ExpensesRepository` (`dayExpenses` read once, `createExpense`, `updateExpense`, `deleteExpense`, `getExpense`), expenses list by day at `/admin/finance/expenses` (Finance tab strip with a Payouts placeholder for 8B), expense form at `/admin/finance/expenses/new` and `/:id/edit` with delete.
- Rules: `dailySummaries` read Admin; `summaryEvents` nobody; `expenses` update by Admin (manual: business fields; others: soft-delete fields only). Rules tests; `integration_test/admin_summaries_flow_test.dart`.

**8B — payouts, reports, visit corrections.** Built 6 Nov 2026 test-first at the seams agreed with the owner (decisions in §1); awaiting the owner's screen review together with 8A. Tests: 771 Flutter tests in all after 8B (new: `test/features/visits/visit_correction_rules_test.dart`, `visit_corrections_repository_test.dart`, `visit_corrections_vms_test.dart`, `visit_corrections_screens_test.dart`; `test/features/finance/payout_rules_test.dart`, `payouts_repository_impl_test.dart`, `payouts_vms_test.dart`, `payouts_screens_test.dart`; `test/features/analytics/report_tables_test.dart`, `reports_vm_test.dart`, `reports_screen_test.dart`), 194 Functions and rules tests in all (5 new rules tests for `payouts`, 1 for visit corrections, 1 Functions test for a doctor change), and `integration_test/admin_visit_corrections_flow_test.dart` (Admin edits Ali's fee 1,500 → 1,200 with a reason → Revenue moves → creates a payout for Dr Multi over last month → Mark paid → the payout expense is on today's list and the Expenses tile → Mark unpaid with a reason → the tile returns → exports Revenue by doctor as CSV).
- Visit corrections (`features/visits/`): `VisitCorrectionRules` (eligible doctors, validation, "nothing changed", day filter), `VisitsRepository.visitsOn` / `correctVisit` / `deleteVisit`, `AdminVisitsViewModel` + `AdminVisitsView` at `/admin/visits` (day strip, text filter, deleted rows), `VisitCorrectionViewModel` + `VisitCorrectionView` at `/admin/visits/:id/edit`, Edit and Delete (`DeleteVisitDialog`) on the Admin visit detail; `Visit` gains `deleteReason` and `editReason`.
- Payouts (`features/finance/`): `Payout`, `PayoutRules` (compute from `byDoctor`, validation, last-month default, overlaps, state checks, expense note), `PayoutsRepository` (`createPayout`, `listPayouts`, `getPayout`, `markPaid`, `unmarkPaid`, `deletePayout`), `PayoutsListView` (Finance → Payouts tab), `NewPayoutView` at `/admin/finance/payouts/new`, `PayoutDetailView` at `/admin/finance/payouts/:id` with the Mark paid / Mark unpaid / Delete dialogs.
- Reports (`features/analytics/`): `DailySummary` gains `discountsByUser` / `discountsByReason` (`CountAmount`), `ReportSection` / `ReportTables` / `ReportCsv`, `FileSaver` (`core/storage/`), `ReportsViewModel` + `ReportsView` at `/admin/reports` (Reports sidebar destination, under More on phones).
- Rules: `payouts` opened; `visits` Admin update needs `editReason` and keeps the department. Rules tests; Functions test; the Chrome flow above.

### Phase 9 — Hardening and release
Code built 6 Nov 2026 test-first at the seams agreed with the owner (decisions in §1); awaiting the owner's screen review of the audit log together with Phases 1–8B, then the owner steps below.
- Audit log: `functions/src/audit.ts` (`auditWriteCore` + nine `audit*` triggers), rules (`auditLogs` Admin read), `features/audit/` (`AuditEntry`, `AuditCollection`, `AuditAction`, `AuditFilter`, `AuditLogsRepository.dayEntries`, `AuditLogViewModel` + `AuditLogView` at `/admin/audit`; Audit log sidebar destination under More on phones).
- App Check: `core/firebase/app_check_config.dart` (pure provider choice, unit-tested) activated from `bootstrapFirebase` (never blocks start-up). Release web builds pass `--dart-define=RECAPTCHA_SITE_KEY=<key>`.
- Test admin removed: `functions/src/test_admin.ts`, `DevToolsRepository`, the login button and `ALLOW_TEST_ADMIN` are gone; `functions/.env` keeps no params.
- Release prep: `firebase.json` Hosting cache headers (immutable hashed assets, no-cache `index.html`, service worker and `version.json`); `android/app/build.gradle.kts` signs release builds from `android/key.properties` (template in `android/key.properties.example`) with minify and `proguard-rules.pro`; iOS keeps bundle ID `ramzan.shop.ramzan` and the generated `GoogleService-Info.plist`.
- Tests: 776 Flutter tests in all after Phase 9 (new: `test/features/audit/` entity, filter, model, repository, view model and view; `test/core/firebase/app_check_config_test.dart`), 197 Functions and rules tests (6 in `functions/test/audit.test.ts`, 1 rules test for `auditLogs`; the 3 `createTestAdmin` tests are gone), thirteen Chrome flows (`admin_visits_audit_flow_test.dart` runs after `admin_visit_corrections_flow_test.dart` and finds its correction in the log).

**Owner steps to go live** (in this order; the session cannot deploy):
1. `cd functions && npm run build && cd .. && firebase deploy --only functions,firestore:rules,firestore:indexes,storage` — first deploy of every Function (user management, patient numbers, summaries, audit), rules and the two composite indexes.
2. Console → Firestore → TTL: add a policy on `summaryEvents.expiresAt` (`gcloud firestore fields ttls update expiresAt --collection-group=summaryEvents --enable-ttl`).
3. Console → Authentication: delete `admin@mytester.com` if it exists on the live project.
4. Console → App Check: register the web app with a reCAPTCHA v3 site key, Android with Play Integrity, iOS with App Attest; add the debug tokens printed by debug builds; leave enforcement off until the release builds are in use, then enforce Firestore, Functions and Storage.
5. Web: `flutter build web --release --dart-define=RECAPTCHA_SITE_KEY=<key>` then `firebase deploy --only hosting`.
6. Android: create the upload keystore (`keytool -genkey -v -keystore android/keystore/upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`), copy `android/key.properties.example` to `android/key.properties` and fill it in, then `flutter build appbundle --release`.
7. iOS: open `ios/Runner.xcworkspace`, set the team and signing for bundle ID `ramzan.shop.ramzan`, `flutter build ipa --release`, upload with Transporter or Xcode Organizer.

### Phase 10 — Deferred polish
Scope decided 6 Nov 2026 (decisions in §1); built test-first at the agreed seams.
- Reports: Export PDF per section (`ReportPdf` in `features/analytics/presentation/pdf/`, `ReportsViewModel.exportPdf`, button `report-export-pdf-<key>`), printed through `ReceiptPrinter`.
- Margins: `SaleLine.unitCost` snapshot of `purchasePrice` (`NewSaleViewModel.addItem` / `addLens`), `salesCost` and `salesCostByCategory` from `saleContribution` and `recomputeDayCore`, `DailySummary.salesCost` / `salesCostByCategory`, `ReportSection.salesMargins`.
- Version footer: `AppVersion.current` (`lib/core/app_version.dart`), shown in the sidebar footer, rail tooltip and phone user menu (`app-version`).
- Theme colour: `ThemeColor` (`lib/core/theme/theme_color.dart`), `ClinicSettings.themeColor`, `AppTheme.light(seed:)` / `dark(seed:)`, `ClinicApp` watches `SettingsController`, settings swatches `settings-colour-<key>`.
- Tests: 794 Flutter tests after Phase 10 (18 new: `test/core/app_version_test.dart`, `test/core/theme/theme_color_test.dart`, `test/features/analytics/report_pdf_test.dart`, plus cases in the shell, theme, app, settings, sales and analytics files), 199 Functions and rules tests (2 new in `functions/test/summaries.test.ts`), fourteen Chrome flows (`admin_theme_version_flow_test.dart` runs after `admin_summaries_flow_test.dart` and leaves the colour teal). The new rail test exposed a pre-existing overflow: Admin's rail with labels did not fit 800 px, so the rail now scrolls (`LayoutBuilder` + `SingleChildScrollView` + `IntrinsicHeight`) and the footer stays at the bottom when there is room.
- Awaiting the owner's screen review together with Phases 1–9.

---

## 7. Testing Strategy

| Level | What | Tools | Where it runs |
|---|---|---|---|
| Unit | Use cases, view models, utils (fee math, token, patient number, search keys, Karachi dates, summary deltas) | `flutter_test`, `mocktail` | Local, no Firebase |
| Data | Repositories against in-memory Firestore | `fake_cloud_firestore` | Local |
| Widget | Every screen with mocked view models: renders, validation, role visibility | `flutter_test` | Local |
| Integration | Login → create visit → token → queue → summary; offline visit creation (`disableNetwork`); doctor prescription; sale; Admin corrections, payouts and a CSV export; the audit row of a correction | `integration_test` on Chrome via `tool/integration_test_web.sh` (`flutter drive -d web-server` + ChromeDriver); Android emulator later. Never `pumpAndSettle` (focused fields never settle on web): poll with the `waitFor` helpers in `integration_test/login_flow_test.dart`. | Firestore **emulator** with seed data |
| Rules | Allow/deny matrix per collection from FIREBASE_ARCHITECTURE §6 | `@firebase/rules-unit-testing` | Emulator |
| Functions | Each function with emulated Firestore | Jest | Emulator |

Coverage is not a target number. Every phase's listed flows must have a test before the phase is called done.

---

## 8. Coding Conventions

- Dart: `flutter_lints` defaults plus `prefer_const_constructors`, `always_declare_return_types`, `avoid_dynamic_calls`.
- Entities are immutable with `const` constructors. Models convert to and from `Map<String, dynamic>` only; Firestore types never leak into `domain/` or `presentation/`.
- View models expose state fields and intent methods. Widgets never call Firestore directly.
- Money is `int` PKR everywhere. Dates stored as `YYYY-MM-DD` strings come only from `KarachiDate`.
- Every Firestore write that must survive offline goes through a `WriteBatch` built in the repository.
- One screen per file. File names snake_case, classes PascalCase, no abbreviations except `vm`.

---

## 9. Open Points

1. **Theme colour editable by Admin**: resolved 6 Nov 2026, built in Phase 10 (fixed palette in Settings).
2. **Google Analytics** on the Firebase project is optional and unused by the app.
3. **Shell online/offline badge (`SyncBadge`)**: resolved 4 Nov 2026, built in Phase 4 on the today's-visits listener (FIREBASE_ARCHITECTURE §9).
4. **Sidebar version footer**: resolved 6 Nov 2026, built in Phase 10 from `AppVersion.current` with a test against `pubspec.yaml` (no `package_info_plus`).
5. **macOS desktop integration run** (`flutter test integration_test -d macos`) signs in but never reaches the role home on 2 Nov 2026; not investigated because tests run on Chrome (see Phase 1). Revisit only if a desktop target is ever needed.

Resolved 31 Oct 2026: integration tests run on the Firestore emulator, never on the live project (see §1 Test backend).
