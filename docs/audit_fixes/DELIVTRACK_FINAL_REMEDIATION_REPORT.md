# DelivTrack — Final remediation report (8 Nov 2026)

## Executive summary
The 22 applicable findings of the full audit were processed one at a time (investigate → test → fix → verify → report), each as its own local commit on `dev` (nothing pushed, deployed or changed in Firebase). Public sign-up stays enabled (DT-001 skipped by decision) and backup work stays excluded (DT-005). Money, status, customer snapshot, reference uniqueness, review completion and audit entries are now enforced by the Firestore rules and covered by two-user emulator tests; the repositories and auth are covered by about 60 real-transaction tests on an Android emulator; the project is formatted, analysed cleanly and has an (inactive) CI workflow.
**Of the 24 findings: 12 are FIXED AND VERIFIED, 9 PARTIALLY FIXED (the remainder needs the owner, a trusted server or a physical phone), 1 NOT REPRODUCED as a defect, 2 EXCLUDED BY OWNER (DT-001, DT-005).** Details and honest limits are in each `DT-XXX_FIX_REPORT.md` and in `REMAINING_BLOCKERS.md`.

## Issue status
| ID | Sev. | Final status | Main files | Tests / verification | Remaining risk |
|---|---|---|---|---|---|
| DT-001 | High | **EXCLUDED BY OWNER** — public registration approved; the single-account recommendation is not applied. (Live probe on 8 Nov: sign-up works, isolation holds, test data deleted.) | — | Probe only | No App Check / quota protection until the owner acts |
| DT-002 | High | **PARTIALLY FIXED** | `firestore.rules`, `parcel_repository.dart` | rules 7 new tests + mutation check; 29 repository tests | Line totals / expected = sum cannot be enforced by rules |
| DT-003 | High | **FIXED AND VERIFIED** | rules, `parcel.dart`, repository, details screen | rules + widget + domain + emulator | none known |
| DT-004 | High | **PARTIALLY FIXED** | `test_emulator/*`, `.github/workflows/ci.yml`, `firestore_failure_test` | emulator suites pass; CI never run | Offline NOT VERIFIED; CI unverified; repositories not in lcov |
| DT-005 | High | **EXCLUDED BY OWNER — OWNER-MANAGED FIREBASE BACKUP** | — | Nothing changed | Owner's responsibility |
| DT-006 | Med | **PARTIALLY FIXED** | rules, repository | 9 rules tests + mutation; emulator | "Other" service names app-enforced |
| DT-007 | Med | **PARTIALLY FIXED** | rules, repository | 5 rules tests + mutation; emulator | Entries can still be omitted (no server) |
| DT-008 | Med | **FIXED AND VERIFIED** | rules, repository, correction sheet | 6 rules, widget, emulator (backdated parcel) | none known |
| DT-009 | Med | **FIXED AND VERIFIED** | `parcel.dart`, repository, dashboard notice | 15 unit + 3 widget + emulator | Damaged parcel hidden until repaired (notice shown) |
| DT-010 | Med | **FIXED AND VERIFIED** | repository, dashboard stats, payments VM, customer details, report VM | 7 new + emulator | none known |
| DT-011 | Med | **FIXED AND VERIFIED** | rules, `Parcel`, repository, review sheet | 6 rules, 4 widget, domain, emulator | none known |
| DT-012 | Med | **PARTIALLY FIXED** | repository (payments cache) | emulator load test (600 parcels: 600 queries/5,058 ms → 0 after cache; 1 query after a change) | 1k/10k not run; billing not measured; no pagination (by design) |
| DT-013 | Med | **PARTIALLY FIXED** | Settings text, checklist, plan | settings test; existing reminder tests | **NOT VERIFIED — PHYSICAL DEVICE REQUIRED**; D17 not built |
| DT-014 | Low | **PARTIALLY FIXED** | emulator test, report | account-switching test | Cache stays on disk; clearing researched and rejected as unsafe/unsupported |
| DT-015 | Low | **PARTIALLY FIXED** | validators, sign-up, auth tests | unit + widget + real `FirebaseAuthRepository` on emulator | Server-side policy/email verification are console decisions |
| DT-016 | Low | **FIXED AND VERIFIED** | `android/app/build.gradle.kts` | release fails without key; release/debug builds; signer check; launch on emulator | No crash reporting (approval needed) |
| DT-017 | Low | **FIXED AND VERIFIED** | whole `lib/`, `test/`, `test_emulator/` (format only) | format check exit 0; analyze; tests | none |
| DT-018 | Low | **FIXED AND VERIFIED** | `app_router.dart` | 4 routing tests | System back gesture on a phone not tried |
| DT-019 | Low | **FIXED AND VERIFIED** | `pubspec`, splash move, README | pub get, analyze, tests, build | `DelivTrack_Demo_Ready.html` kept |
| DT-020 | Low | **NOT REPRODUCED** (assumption confirmed; tests added, no code change) | `pakistan_time_test.dart` | 8 tests | IANA note not read directly |
| DT-021 | Low | **PARTIALLY FIXED** (no safe project change; owner actions: licences, duplicate adb; upstream KGP warning) | — | doctor/outdated recorded | Warning stays until FlutterFire updates |
| DT-022 | Low | **FIXED AND VERIFIED** | `retry_when_denied.dart` | 7 unit + emulator concurrency | none |
| DT-023 | Low | **FIXED AND VERIFIED** | `firebase.json` | `lsof` before/after; rules + emulator suites | Phones need `adb reverse` |
| DT-024 | Low | **FIXED AND VERIFIED** | requirements v1.3, plan, traceability | text checks; two-user tests | Quota figures not re-checked live |

(Tally: FIXED AND VERIFIED 12 — DT-003, 008, 009, 010, 011, 016, 017, 018, 019, 022, 023, 024; PARTIALLY FIXED 9 — DT-002, 004, 006, 007, 012, 013, 014, 015, 021; NOT REPRODUCED 1 — DT-020; EXCLUDED 2 — DT-001, DT-005.)

## Tests summary (commands run 8 Nov 2026, final state)
- `flutter analyze`: no issues. `dart format --output=none --set-exit-if-changed lib test test_emulator`: exit 0.
- `flutter test --coverage`: **970 passed, 0 failed, 80 skipped** (the skipped are the rules tests, which need the emulator). Baseline was 909 passed / 51 skipped. Line coverage **83.6 %** (3,859 / 4,615; baseline 83.3 %). `parcel_repository`, `customer_repository`, `product_repository` remain 0 % in this number because they are exercised on a device, not in the host VM.
- Firestore rules (emulator, two real users): **80 passed** (baseline 51).
- Repository suites on the Android emulator (`sh test_emulator/run.sh`): auth, parcels, customers, products all passed — runner totals 8 / 38 / 7 / 10 (each includes set-up/tear-down entries).
- Builds: debug APK and release APK (58.6 MB, signed by the upload key CN=DelivTrack; permissions unchanged: INTERNET, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE, READ_GSERVICES, one signature-level permission).
- Mutation checks (rule clause removed → tests fail) for DT-002, DT-006, DT-007 and the archived-money totals.
- Final checks: no secret patterns in the ~21,700 lines added since the baseline commit, no keystore / `key.properties` tracked, no upload/camera/storage package, no billing/backup file touched, no deploy command run.

## Security results
Isolation holds: every path is `users/{uid}/…` with `request.auth.uid == uid`, default deny; 80 two-user rules tests and the emulator account-switching test (second account sees nothing of the first, starts at ADT-000001, may reuse a reference). New: received money moves only with a new payment document in the same commit; payment status must follow the amounts; expected amount cannot change alone; the customer snapshot must match a real customer record; postal-reference guards are created with the parcel and released only when it moves; audit entries must describe a real simultaneous edit; a returned parcel with an open review cannot be archived. Not enforceable without a server: item line arithmetic, omitted audit entries, "Other" service names.

## Financial results
Integer paisa throughout. Payments are an append-only ledger bound to the parcel's received amount. Corrections reverse and re-record, can fix amount, date or both, keep the original and say who/when. Returned parcels keep their money and flagged balance until the review is completed with a reason and note (refund/adjustment never automatic). Archiving keeps received money in lifetime totals, history and customer advance; counts and balances use active parcels. Dashboard totals reconcile with the ledger (tests).

## Remaining problems
See `REMAINING_BLOCKERS.md`: rules not deployed (must go out with the app), abuse protection for open sign-up, physical-phone reminder/offline checks, CI never run, owner decisions (dev dependency, D17, persistence), and the inherent rule limits above.

## Production readiness
**READY WITH CONDITIONS** — not READY: (1) deploy the rules together with the release build; (2) the owner decides and configures abuse protection (App Check, billing alerts, password policy) before relying on open sign-up; (3) run the physical-phone checklist; (4) backups are the owner's. Automated tests do not prove device behaviour or live-project settings.

## Owner actions required
Deploy rules with the release; Firebase console settings (App Check, password policy, enumeration protection, billing alerts); accept Android licences and remove the duplicate adb; run `docs/MANUAL_DEVICE_CHECKLIST.md` on a phone; confirm the `integration_test` dev dependency and whether to activate CI; decide D17 / persistence; decide which extra files to delete (list in the hand-over message — nothing was deleted). Backup implementation is **not** an agent task.
