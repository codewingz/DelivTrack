# DT-016 — Release build could silently use the debug key (LOW)

**Status: FIXED AND VERIFIED** (crash reporting not added, see below)

## Before
`android/app/build.gradle.kts` fell back to the **debug signing key** when `android/key.properties` was missing, so a fresh clone could produce a debug-signed "release" APK without any warning.

## Change
`android/app/build.gradle.kts`: when a release task is requested (`assembleRelease`, `bundleRelease`, …) and `key.properties` has no `storeFile`, Gradle fails with: "Release signing is not configured: android/key.properties is missing (or has no storeFile)…". A local, debug-signed release can still be built on purpose with `-PallowDebugSigning=true`. Debug builds are unaffected. No secret is read or printed by the check.

## Verified (commands run 8 Nov 2026)
- With `android/key.properties` temporarily moved away (and restored afterwards): `flutter build apk --release` → **BUILD FAILED in 1 s** with the message above.
- With the key present: `flutter build apk --release` → built (58.6 MB); `apksigner verify --print-certs` shows the signer **CN=DelivTrack** (upload key; only the subject name was printed). `flutter build apk --debug` → built, signer **Android Debug**.
- Release APK permissions (`aapt2 dump permissions`): INTERNET, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE, READ_GSERVICES, one signature-level dynamic-receiver permission; no camera/storage/location. `usesCleartextTraffic` is not set in the app manifest.
- Release APK installed on the Android emulator and launched: process stayed alive 8 s, no `FATAL EXCEPTION`.
- Secrets: `git ls-files` lists no keystore, `key.properties`, `.pem` or service-account file; `android/key.properties` is git-ignored. `google-services.json` is tracked (public client configuration).
- Code shrinking: R8 already runs on release builds (`build/app/outputs/mapping/release/mapping.txt` exists). Dart obfuscation (`--obfuscate --split-debug-info=<dir>`) is a build flag, not forced here; if used, keep the symbol files to read crash traces.

## Not done
- No Crashlytics / external monitoring (needs owner approval).
- Firebase initialisation and notification delivery on the release build were not exercised beyond start-up (Firebase init runs at start-up without a crash; delivery needs a physical phone).
