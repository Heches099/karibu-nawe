# Farm FMS

Farm work measurement, full-work costing, worker allocation, payment,
collection, handover, and audit tracking application built with Flutter.

## Current Architecture

- Flutter UI for Android, Web, and desktop.
- Local Sembast persistence adapter with offline-first local records.
- Explicit services for calculation, allocation, payment, collection, handover,
  work zones, progress, and audit history.
- Authorization checks at the `AppStore` service boundary.
- Firebase deployment scaffolding in `firebase.json`, `firestore.rules`, and
  `storage.rules`.

The repository does not contain a Firebase project configuration or service
credentials. Firebase Authentication, Firestore synchronization, Storage, and
Hosting deployment must be connected to a real project before production use.
Never commit generated credentials or service-account files.

## Local Development

```powershell
flutter pub get
flutter run -d chrome
```

The local adapter creates an initial administrative account for development.
Replace local authentication with Firebase Authentication before production.
Operational data is not seeded automatically at startup. Tests may call
`seedDemoData()` explicitly to build deterministic fixtures.

## Validation

```powershell
flutter analyze
flutter test
flutter build web
```

The analyzer currently reports lint and deprecation infos but no compile
errors. The test suite and web build must pass before deployment.

## Firebase Preflight

1. Create a Firebase project and enable Email/Password Authentication.
2. Run FlutterFire configuration locally to generate platform options.
3. Implement the Firebase repository/auth adapter and select it through an
	environment-specific composition root.
4. Set `role` custom claims (`boss`, `manager`, `worker`, or `viewer`) from a
	trusted server-side process.
5. Test and deploy `firestore.rules` and `storage.rules` with the Firebase CLI.
6. Build the web app and deploy `build/web` through Firebase Hosting.

The rules deny unknown collections and protect payments, allocations,
handovers, users, and audit records. Rule tests should run with the Firebase
Emulator Suite after a project is configured.

## Secrets

`.env`, Firebase service accounts, private keys, platform configuration files,
and local Firebase state are ignored by `.gitignore`. Use local environment
configuration or FlutterFire-generated client options; never place admin
credentials in Flutter source.
