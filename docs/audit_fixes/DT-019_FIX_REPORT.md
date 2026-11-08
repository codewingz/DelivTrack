# DT-019 — Unused dependencies and project leftovers (LOW)

**Status: FIXED AND VERIFIED**

## Checked before removing
- `dio` and `cupertino_icons`: no import or use in `lib/`, `test/`, `test_emulator/` or Android sources (`grep` for `package:dio`, `Dio(`, `Cupertino…`). `flutter pub remove dio cupertino_icons` changed 4 resolved packages (the two plus their now-unneeded dependencies); no package the app uses was upgraded.
- Splash screen: only the router and one test referenced it.

## Changes
- `pubspec.yaml` / `pubspec.lock`: `dio` and `cupertino_icons` removed.
- `lib/screens/splash_screen.dart` moved to `lib/features/auth/views/splash_screen.dart` (feature-first layout); imports updated in the router and `test/responsive_test.dart`; the empty `lib/screens/` folder is gone.
- `README.md`: the Flutter template replaced with a DelivTrack README (purpose, layout, setup, checks, release signing note, Firebase notes).
- `android/app/build.gradle.kts`: template TODO/boilerplate comments removed; application id (`com.codewingz.delivtrack`) and all behaviour unchanged.

## Verification
`flutter pub get` OK; `flutter analyze` no issues; `dart format --set-exit-if-changed` exit 0; `flutter test` 955 passed; `flutter build apk --debug` built; app icon and Android package identity untouched.

## Left alone (for the owner)
- `DelivTrack_Demo_Ready.html` is the UX prototype named in AGENTS.md (reference only); `DelivTrack_Project_Requirements.md` is the spec; both kept. `audit_evidence/` and `DELIVTRACK_FULL_AUDIT_REPORT.md` are audit artifacts.
- Cleanup of extra files/folders (e.g. `docs/`) is deferred to the end, as the owner asked, and will be listed for confirmation first.
