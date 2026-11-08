# DT-004 — Firestore repositories had no automated tests; no CI (HIGH)

**Status: PARTIALLY FIXED** — real-emulator repository tests exist and pass; the CI workflow is written but has never run (it is not pushed or activated); offline behaviour is NOT VERIFIED.

## Before the fix
`parcel_repository.dart`, `customer_repository.dart` and `product_repository.dart` had 0 % coverage (the emulator integration tests were deleted at the owner's request on 8 Nov 2026) and there was no CI.

## What was added
- `test_emulator/` (**not** `integration_test/`, which stays deleted): `parcels_repository_test.dart` (36 tests), `customers_repository_test.dart` (7), `products_repository_test.dart` (10), `test_helpers.dart`, `driver.dart`, `run.sh`. They are the historic repository tests, brought up to date and extended during this remediation. They use the real repositories, Firebase Auth and Firestore **emulators**, real transactions and the real rules, on an Android emulator.
  Covered: automatic order sequence, five concurrent creations, duplicate/normalised postal references (and three concurrent saves of one reference), payment recording, concurrent and overlapping payments, partial payments, overpayment/zero/long-note/Gift refusals, corrections (amount, date-only, to 0, concurrent corrections), returns, payment-review completion, archive/restore (and archived money kept), customer and product repository operations, cross-user isolation and denied writes, damaged documents, audit entries accepted under the stricter rules.
- Why `flutter drive`: `flutter test -d` only runs plugin-based device tests from a folder named `integration_test/` (verified: a test elsewhere ran on the host VM and failed with "integration_test plugin was not detected"); `flutter drive` with a driver file works from any folder. Run: `firebase emulators:exec --only auth,firestore --project delivtrack-codewingz "sh test_emulator/run.sh <emulator-id>"`.
- Dependency note: the SDK-bundled `integration_test` **dev dependency** was added again (it was removed with the folder). It ships with Flutter, is dev-only and adds nothing to the app. **Owner: please confirm** you are happy to keep it; without it these tests cannot run.
- `lib/core/errors/firestore_failure.dart` unit tests (`test/firestore_failure_test.dart`): the messages for `unavailable`, `deadline-exceeded`, `permission-denied`, `unauthenticated`, `aborted`, unknown codes; stream errors become `AppFailure`, other errors pass through.
- `.github/workflows/ci.yml`: format check (`dart format --set-exit-if-changed lib test test_emulator`), `flutter analyze`, `flutter test --coverage`, the rules tests on the emulator, the repository tests on an Android emulator (reactivecircus/android-emulator-runner, API 34), and a debug APK build. Flutter 3.47.8 and firebase-tools 15.4.0 are pinned to the local versions. Actions use major-version tags (`@v4`, `@v2`).

## Results (commands run locally, 8 Nov 2026)
- `firebase emulators:exec --only auth,firestore --project delivtrack-codewingz "sh test_emulator/run.sh emulator-5554"` → **36 + 7 + 10 = 53 passed**, exit 0.
- `flutter analyze` → no issues. `flutter test` → 947 passed, 80 skipped (rules tests need the emulator, run separately: 80 passed).

## Not verified / limits
1. **Offline transaction failures: NOT VERIFIED.** `FirebaseFirestore.disableNetwork()` does not stop a transaction in this setup (a probe showed a save completing in 18 ms and reaching the server while "offline"), so that test was removed rather than kept as a false pass. Only the error-message mapping is unit-tested. A manual airplane-mode check is still needed (add to the device checklist).
2. **CI has never run.** It was written from the commands that pass locally; GitHub-hosted runners, the emulator action and action versions are unverified until it is first pushed. `dart format` will fail until DT-017 formats the project.
3. Coverage: these device tests are not in the `flutter test --coverage` number, so the lcov percentage for the repositories stays near 0 %. Their coverage is by scenario (list above), not by percentage; no 80 % claim is made.
4. Docs: AGENTS.md now documents the command.
