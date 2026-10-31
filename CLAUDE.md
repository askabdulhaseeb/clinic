# CLAUDE.md — Clinic Management App (`ramzan`)

Flutter + Firebase clinic app. Three roles: Reception (web, offline-capable), Doctor and Admin (Android, iOS, web). Two departments today (Eye, Homeopathy), more addable by Admin.

## Docs are the source of truth

Read before writing code. If code and docs disagree, the docs win; if a requirement is missing, it is not a requirement yet. Propose a doc change first, then code.

| Doc | Owns |
|---|---|
| `docs/FEATURES.md` | What the app does: roles, permissions, data model, every feature per role, out of scope. |
| `docs/FIREBASE_ARCHITECTURE.md` | Collections and fields, Cloud Functions, security rules, Storage layout, indexes, offline strategy. |
| `docs/DEVELOPMENT_PLAN.md` | State management, folder layout, packages, build phases, testing strategy, coding conventions. |
| `docs/UI_DESIGN.md` | Screen inventory, navigation, shell layouts, form layouts. |

When a decision is made in conversation, write it into the relevant doc (decisions table plus the affected section) in the same change as the code.

## Working with the owner

- Ask requirement questions as selectable options, never assume.
- Each build phase ends with the owner reviewing screens. Do not call a phase done before that.

## Architecture (summary, details in DEVELOPMENT_PLAN §4–§8)

- Feature-first clean architecture: `lib/features/<feature>/{domain,data,presentation}`. Shared code in `lib/core/`.
- State: `provider` + `ChangeNotifier` view models. No Riverpod, Bloc, GetX.
- Models: plain Dart with hand-written `fromMap`/`toMap`/`copyWith`. No `freezed`, no `build_runner` for models.
- Routing: `go_router`, role-based redirect after login.
- Firestore types never leak into `domain/` or `presentation/`. Widgets never call Firestore directly.
- Money is `int` PKR. Clinic-day dates are `YYYY-MM-DD` strings from `KarachiDate` only (timezone Asia/Karachi).
- Every write that must survive offline goes through a `WriteBatch` built in the repository.
- Soft deletes only (`deleted`, `deletedAt`, `deletedBy`, `deleteReason`). Queries filter `deleted == false`.
- Every business document carries `branchId` (default `main`).
- One screen per file, snake_case files, PascalCase classes, no abbreviations except `vm`.

## Commands

```sh
flutter pub get
flutter analyze
dart format lib test
flutter test                       # unit + widget
flutter test integration_test      # needs the Firebase emulators running
firebase emulators:start           # Firestore, Auth, Functions, Storage (after firebase init)
cd functions && npm test           # Cloud Functions + rules tests (Jest, emulator)
```

Run `flutter analyze` and `flutter test` before saying a change is done.

## Firebase

- Project `ramzan-clinic-web`, region `asia-south1`, Blaze plan. `lib/firebase_options.dart` is generated; do not hand-edit.
- The app talks to the live project in development. All tests use the local Emulator Suite, never live data.
- Functions: 2nd gen, TypeScript, Node 22, in `functions/`. Build with `npm run build` there; `firebase deploy` runs it as a predeploy step.
- Deploys (`firebase deploy ...`) are run by the owner, not by AI sessions.
- App IDs: `ramzan.shop.ramzan`. Launcher name and browser title: Clinic.

## Current status

Phase 0 (project setup) is done: Firestore, Auth and Blaze enabled, Firebase config files and `functions/` scaffold in place, rules deny everything. Next: Phase 1 (Auth and users). Phase list in DEVELOPMENT_PLAN §6.
