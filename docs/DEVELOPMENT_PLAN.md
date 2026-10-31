# Development Plan

Draft v3 — 31 Oct 2026. v3: integration tests fixed on the Firestore emulator (open point 1 closed). Companion to [FEATURES.md](FEATURES.md) and [FIREBASE_ARCHITECTURE.md](FIREBASE_ARCHITECTURE.md). This document fixes the technical choices for the Flutter code and the order in which features are built.

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
| Firebase project | `ramzan-clinic-web` (project number 662931473606), created by the owner. Android, iOS, web and Windows apps registered; `lib/firebase_options.dart` generated. Firestore, Auth (Email/Password) and Blaze enabled on 31 Oct 2026. Storage bucket `ramzan-clinic-web.firebasestorage.app` is configured in the SDK; its existence is confirmed by the first `firebase deploy --only storage`. |
| Dev backend | Flutter app talks to the live Firebase project during development. Cloud Functions and rules are developed on the local Emulator Suite, then deployed. |
| Test backend | All integration, rules and functions tests run against the local Firestore Emulator Suite with seed data. Tests never touch the live project. No second Firebase project. |
| Automated tests | Full: unit tests (domain + view models), widget tests (every screen), integration tests (key flows). Firestore rules tests on the emulator. |
| App identifier | `ramzan.shop.ramzan` for Android package and iOS bundle ID. Android minSdk 23, iOS 15.0. |
| Cloud Functions runtime | 2nd gen, TypeScript, Node 22 runtime (local Node 24 is fine for tooling). |
| Version control | Git initialised by the owner on 31 Oct 2026, branch `main`. Commit at the end of each phase at least. |

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
5. **Storage**: Build → Storage → Get started → location `asia-south1` → production mode.
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
  features/
    auth/                       # login, mustChangePassword, current user + roles
    settings/                   # settings/general, logo upload, receipt copies, WhatsApp toggles
    users/                      # Admin: user list, create, roles (calls createUser/setUserRoles)
    catalog/                    # departments, doctors (fees, salary, share), visitTypes
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
    users.ts  patients.ts  summaries.ts  audit.ts  families.ts  backup.ts
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
| `image_picker`, `flutter_image_compress` | Prescription photos, resize to 1600 px |
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
- Login screen, forced password change, role-based landing (Reception / Doctor / Admin shells).
- Functions: `createUser`, `setUserRoles` (custom claims).
- Admin: user list, create user, edit roles, deactivate.
- Rules: `users` collection, role helpers.

### Phase 2 — Admin master data
- Settings: clinic name, logo, default receipt copies, WhatsApp reminder toggles and templates.
- Departments (name, code), doctors (salary, share %, share basis, fee grid), visit types (operation flag, follow-up flag, default checklist, post-op days).
- Seed script for first Admin + two departments.

### Phase 3 — Patients and families
- Family lookup by phone, create family, add patient, move patient between families, change family phone (duplicate check function).
- Patient search by name prefix and phone (offline).
- Temp IDs offline, `assignPatientNo` function, counter per year.
- Full patient history view (used by Doctor in Phase 5).

### Phase 4 — Reception visit flow
- New visit: patient → doctor → visit type → fee auto → discount + reason → payment method → token.
- Receipt PDF (A4, copy count), print.
- Today's queue per doctor, status changes, visit list for the day.
- Shift summary screen.
- Offline behaviour verified by integration test with network disabled.

### Phase 5 — Doctor
- Own queue, patient history across departments.
- Prescription: typed (Eye SPH/CYL/AXIS/ADD/VA per eye, Homeo medicine/potency/dosage/duration), photo, both. Prescription PDF.
- Reports upload (Reception) and view (Doctor).
- Operations: record, checklist with override reason, post-op days → appointments created.
- Doctor personal summary.

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
- `recomputeDailySummary` function, dashboard reading `dailySummaries` only.
- Date-range reports, discounts by user/reason, department and doctor breakdown, CSV export.
- Visit corrections and soft delete (Admin).

### Phase 9 — Hardening and release
- Audit log functions and Admin viewer.
- App Check, daily backup function, composite indexes deployed.
- Hosting deploy for web, Android release build, iOS build.
- Final full test run.

---

## 7. Testing Strategy

| Level | What | Tools | Where it runs |
|---|---|---|---|
| Unit | Use cases, view models, utils (fee math, token, patient number, search keys, Karachi dates, summaries) | `flutter_test`, `mocktail` | Local, no Firebase |
| Data | Repositories against in-memory Firestore | `fake_cloud_firestore` | Local |
| Widget | Every screen with mocked view models: renders, validation, role visibility | `flutter_test` | Local |
| Integration | Login → create visit → print receipt; offline visit creation; doctor prescription; sale | `integration_test` on Chrome and Android emulator | Firestore **emulator** with seed data |
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

Resolved 31 Oct 2026: integration tests run on the Firestore emulator, never on the live project (see §1 Test backend).
