# Development Plan

Draft v9 — 5 Nov 2026. v9: Phase 5B decisions and build notes (reports with client resize, operations with appointments regenerated in one batch, doctor edits of operation-type defaults, visit–operation link). v8: Phase 5 split into checkpoints 5A and 5B, Phase 5A decisions and build notes (doctor queue on the shared today listener, consultation with Save / Complete, prescription PDF, follow-up appointments, aggregate summary). v7: Phase 4 decisions and build notes (visit flow, receipt PDF, queue, summary, sync badge, offline integration test). v6: Phase 3 built (families, patients, search, patient page, patient-number and duplicate-phone triggers, offline cache listeners). v5: Phase 2 built (settings, catalog, first-run setup, doctor picker, shared integration helpers). v4: budget decisions (Storage bucket us-central1, no backup, typed-only prescriptions, incremental summaries) applied to phases and setup steps. Companion to [FEATURES.md](FEATURES.md) and [FIREBASE_ARCHITECTURE.md](FIREBASE_ARCHITECTURE.md). This document fixes the technical choices for the Flutter code and the order in which features are built.

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
| Cost | Stay inside Blaze no-cost quotas at 500 visits a day (FIREBASE_ARCHITECTURE §11). No photo prescriptions, no managed backup, summaries by increments. |
| Dev backend | Flutter app talks to the live Firebase project during development. Cloud Functions and rules are developed on the local Emulator Suite, then deployed. |
| Test backend | All integration, rules and functions tests run against the local Firestore Emulator Suite with seed data. Tests never touch the live project. No second Firebase project. |
| Automated tests | Full: unit tests (domain + view models), widget tests (every screen), integration tests (key flows). Firestore rules tests on the emulator. |
| App identifier | `ramzan.shop.ramzan` for Android package and iOS bundle ID. Android minSdk 23, iOS 15.0. |
| Cloud Functions runtime | 2nd gen, TypeScript, Node 22 runtime (local Node 24 is fine for tooling). |
| Test admin (dev only) | Decided 2 Nov 2026: the login screen shows a **Create test admin** button in debug builds only (`kDebugMode`). It calls `createTestAdmin`, which creates or restores `admin@mytester.com` / `1234567890` as an active admin, then signs in. The function only works while `functions/.env` has `ALLOW_TEST_ADMIN=true`. Phase 9 turns it off and deletes the account. Needs the function deployed (owner) to work against the live project; works on the emulators today. |
| Version control | Git initialised by the owner on 31 Oct 2026, branch `main`. Commit at the end of each phase at least. |
| Phase 4 decisions (4 Nov 2026) | Reception may move visits to in progress and completed (rules opened for `status`, `startedAt`, `completedAt`). Discount reasons are a preset list plus Other with free text (`DiscountReasons`). Shift summary is clinic-wide with a "My visits only" switch. Fee is read-only on the form; a missing fee blocks save. Visits page lists today only; history and reprint live on the patient page. One `TodayVisitsController` holds the today's-visits listener for the list, queue, summary, sync badge and the waiting count. Tokens come from a cache-only query. Receipt PDF is built with `pdf` behind a `ReceiptPrinter` abstraction (`printing` in the app, a fake in tests). Offline is exercised in the Chrome test with `disableNetwork()` / `enableNetwork()` on the Firestore instance. Reception writes go through `commitOrQueue` (wait 1.5 s for the server, then treat as queued) because Firestore only resolves write futures on acknowledgement; applied to the Phase 3 patient writes too. Admin gets the same visit routes under `/admin/visits/...` since Admin may create visits too; `/admin/visits` itself stays a placeholder until Phase 8. |
| Phase 5B decisions (5 Nov 2026) | Surgery day is booked as a `source: operation` appointment next to the post-op ones; the surgeon is any active doctor of the department (self preselected); the new-visit form links a token to the patient's scheduled operation of that type (`visits.operationId`) and shows the date; reception and Admin soft-delete reports with a reason; uploads start from the patient page's Reports tab (title, file or camera, optional visit); Mark done needs every item ticked or an override reason. Code: `features/reports/` (entity, `ReportFiles` checks, repository over `FileStore` + `ImageShrinker`, upload dialog, Reports tab), `features/operations/` (entity, `OperationRules`/`PostOp`, repository, schedule sheet, list, detail), Me-tab defaults editor in `features/visits/` reusing the catalog's checklist and post-op editing logic. Pickers (`file_picker`, `image_picker`) and the shrinker sit behind typedefs/interfaces so widget tests inject bytes. Seams agreed with the owner: domain, repositories + rules (Firestore and Storage) on the emulator, view models and widgets, one Chrome flow for operations (the browser file dialog cannot be driven, so upload is covered at the repository and widget seams). |
| Phase 5 decisions (5 Nov 2026) | Delivered in two owner checkpoints: 5A (queue, consultation, prescriptions + PDF, history, personal summary) and 5B (reports, operations, operation-type defaults). Follow-up dates write `appointments` documents at once (Phase 6 adds the screens). Save and Complete are separate; Complete without a prescription confirms first. The assigned doctor edits a prescription until the end of its Karachi day (rules compute the cut-off from `date`). Follow-up date via quick chips plus a picker. Me tab: completed-visit counts and own gross/discount/net for today, week (from Monday) and month through aggregate queries (`count` + `sum`, one read per period, needs the `doctorId, status, deleted, date` index). `TodayVisitsController` also serves doctor-only sessions with a doctor-scoped query. Code lives in `features/prescriptions/` (entity, rules, repository, consultation, PDF), the doctor queue and summary in `features/visits/`, the doctor history page in `features/patients/`; the appointment write is a model in `features/appointments/data/`. Test seams agreed with the owner: domain (Rx validation, summary periods, follow-up dates), repositories on fake Firestore plus rules on the emulator, view models and widgets per screen, one Chrome flow. |
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
- Patient search by phone (family or personal), patient number, temp number and name prefix, grouped by family. Offline: `PatientCacheController` keeps the `families` and `patients` listeners open for reception sessions.
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
- Appointment create/edit, free-text time, sources manual/followUp/postOp.
- Due-today list, WhatsApp pre-filled link, mark sent.
- Convert appointment into visit.

### Phase 7 — Inventory and sales
- Items: medicine, frame, lens (power grid), consumable. Stock via increments + `stockMovements`.
- Suppliers, purchase bills (create expense).
- Reception sales with receipt, stock deduction.

### Phase 8 — Finance and analytics
- Expenses (manual), payouts (date range, salary prefilled, share by basis).
- `applyDailySummaryDelta` function (increments, idempotent via `summaryEvents` with TTL), `recomputeDay` repair callable, dashboard reading `dailySummaries` only.
- Date-range reports, discounts by user/reason, department and doctor breakdown, CSV export.
- Visit corrections and soft delete (Admin).

### Phase 9 — Hardening and release
- Remove the dev test admin: set `ALLOW_TEST_ADMIN=false` in `functions/.env`, redeploy, delete `admin@mytester.com`.
- Audit log functions and Admin viewer.
- App Check, composite indexes deployed, Firestore TTL policy on `summaryEvents.expiresAt`.
- Hosting deploy for web, Android release build, iOS build.
- Final full test run.

---

## 7. Testing Strategy

| Level | What | Tools | Where it runs |
|---|---|---|---|
| Unit | Use cases, view models, utils (fee math, token, patient number, search keys, Karachi dates, summary deltas) | `flutter_test`, `mocktail` | Local, no Firebase |
| Data | Repositories against in-memory Firestore | `fake_cloud_firestore` | Local |
| Widget | Every screen with mocked view models: renders, validation, role visibility | `flutter_test` | Local |
| Integration | Login → create visit → token → queue → summary; offline visit creation (`disableNetwork`); doctor prescription; sale | `integration_test` on Chrome via `tool/integration_test_web.sh` (`flutter drive -d web-server` + ChromeDriver); Android emulator later. Never `pumpAndSettle` (focused fields never settle on web): poll with the `waitFor` helpers in `integration_test/login_flow_test.dart`. | Firestore **emulator** with seed data |
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

1. **Theme colour editable by Admin** was not chosen. Teal is fixed in code for v1.
2. **Google Analytics** on the Firebase project is optional and unused by the app.
3. **Shell online/offline badge (`SyncBadge`)**: resolved 4 Nov 2026, built in Phase 4 on the today's-visits listener (FIREBASE_ARCHITECTURE §9).
4. **Sidebar version footer** (`v1.0.0` in UI_DESIGN §2.1) is not shown yet; needs `package_info_plus` or a build-time constant. Owner to confirm it is wanted.
5. **macOS desktop integration run** (`flutter test integration_test -d macos`) signs in but never reaches the role home on 2 Nov 2026; not investigated because tests run on Chrome (see Phase 1). Revisit only if a desktop target is ever needed.

Resolved 31 Oct 2026: integration tests run on the Firestore emulator, never on the live project (see §1 Test backend).
