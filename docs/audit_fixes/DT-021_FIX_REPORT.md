# DT-021 — Android toolchain warnings (LOW)

**Status: PARTIALLY FIXED — nothing safe to change in the project; two items are owner actions on the Mac, one is an upstream plugin issue.**

## Findings (8 Nov 2026)
| Warning | Cause | Action |
|---|---|---|
| Build prints "plugins that apply the Kotlin Gradle Plugin: firebase_auth, firebase_core… future versions of Flutter will fail" | The latest published versions of both plugins still apply KGP: `flutter pub outdated` shows **every direct and dev dependency already at its latest version** (`firebase_auth`, `firebase_core`, `cloud_firestore`, `flutter_local_notifications`, `go_router`, `url_launcher`…) | **Upstream.** Nothing to upgrade today. Track FlutterFire releases that adopt built-in Kotlin; the warning is non-blocking with Flutter 3.47.8, AGP 9.1.0, Gradle 9.3.1, Kotlin plugin 2.4.0 (build and tests pass). Do not pin or downgrade the toolchain |
| `flutter doctor`: "Some Android licenses not accepted" | SDK licence agreements not accepted on this Mac | **Owner action:** run `flutter doctor --android-licenses` and read and accept the licences. Not done by the agent: accepting is a legal agreement on the owner's behalf. Builds currently work with the already-installed SDK components |
| `flutter doctor`: "Multiple adb binaries found" (`~/Library/Android/sdk/platform-tools/adb` and Homebrew `/opt/homebrew/Caskroom/android-platform-tools/…`) | Two installs of platform-tools | **Owner action:** keep one (e.g. `brew uninstall --cask android-platform-tools`, or put the SDK one first on `PATH`). A version mismatch can restart the adb server and drop the emulator connection; during this work the emulator stayed connected |

## Verification (no change was made, so this records the current state)
`flutter doctor -v` (Android toolchain `[!]` for the two items above only), `flutter analyze` clean, `flutter test` 955+ passed, debug APK and release APK built (DT-016/DT-019), emulator suite passes. Material colour utilities / `test_api` transitive updates are available but unnecessary and were not applied.
