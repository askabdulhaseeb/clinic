# Clinic Management App

A Flutter app for a multi-department clinic (Eye and Homeopathy today, more later) with three roles: Reception, Doctor, and Admin.

- Reception works on the web at the front desk and keeps working offline.
- Designed to run inside Firebase free quotas at up to 500 visits a day.
- Doctors and Admin use the mobile app (Android, iOS) or the web.
- Backend is Firebase.

## Documentation

- [Feature Specification](docs/FEATURES.md) — the source of truth for what the app does. Read this before writing code.
- [Firebase Architecture](docs/FIREBASE_ARCHITECTURE.md) — collections, fields, security rules, Cloud Functions, offline strategy.
- [Development Plan](docs/DEVELOPMENT_PLAN.md) — state management, folder layout, packages, build phases, testing strategy, Firebase project setup steps.
- [UI Design](docs/UI_DESIGN.md) — shells, navigation map, key screen layouts, shared widgets, print layouts.

## Getting started

```sh
flutter pub get
flutter run
```

Firebase project setup steps and the folder layout are in [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md).
