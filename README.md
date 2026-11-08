# DelivTrack

Android app (Flutter) for tracking Pakistan Post parcels, customers and payments. Anyone can sign up; every account sees only its own data (Firebase Auth + Cloud Firestore, one private data tree per user).

## What it does
Parcels with automatic order numbers, products (per piece / per kg), Post Office collection, advance, Pay Later (with phone reminders), Gift / Free, returns and payment review, partial payments with a correction history, search and filters, dashboard, reports, archive and restore.

## Project layout
- `lib/features/<feature>/{data,domain,viewmodel,views}` — feature-first MVVM (auth, customers, dashboard, parcels, payments, products, reminders, reports, settings, more); `lib/common_widgets`, `lib/design_system`, `lib/core`, `lib/routes` (go_router).
- `firestore.rules` — security rules (per-user isolation, money and audit integrity); `firestore.indexes.json`.
- `test/` unit and widget tests; `test/rules/` rules tests; `test_emulator/` repository tests on an Android emulator.
- `docs/` plan, requirement traceability, backup notes, device checklist, `docs/audit_fixes/` remediation reports. `AGENTS.md` has the working rules.

## Set up
1. Flutter 3.47.8 (stable) and the Android SDK; Firebase CLI for the emulators (`firebase --version`).
2. `flutter pub get`.
3. `flutter run` on an Android device or emulator (it talks to the real Firebase project `delivtrack-codewingz`; use a test account).

## Check it
```
dart format --output=none --set-exit-if-changed lib test test_emulator
flutter analyze
flutter test
firebase emulators:exec --only auth,firestore --project delivtrack-codewingz "flutter test test/rules"
# with an Android emulator running:
firebase emulators:exec --only auth,firestore --project delivtrack-codewingz "sh test_emulator/run.sh <emulator-id>"
```

## Release build
`flutter build apk --release` (or `appbundle`) needs `android/key.properties` pointing at the upload keystore (kept outside the repository, never committed). Without it the build stops with a clear message; `-PallowDebugSigning=true` allows a local, debug-signed build that must not be published.

## Firebase
Rules and indexes are deployed with the Firebase CLI only after the emulator tests pass (see `AGENTS.md`). Backups are managed by the owner outside the code (`docs/BACKUP_AND_RESTORE.md`).
