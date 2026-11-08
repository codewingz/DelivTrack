# Baseline report (before remediation)

Date: 8 Nov 2026. Source audit: `DELIVTRACK_FULL_AUDIT_REPORT.md`.

| Item | Value |
|---|---|
| Branch / commit | `dev` @ `ebf1a5b` |
| Working tree | untracked only: `DELIVTRACK_FULL_AUDIT_REPORT.md`, `audit_evidence/` (probe tests). No tracked changes |
| Flutter | 3.47.8 stable (rev `737ba8f885`) |
| `flutter doctor -v` | Flutter, Xcode, Chrome, network OK. **!** Android licences not accepted; **!** multiple `adb` binaries (DT-021) |
| `flutter analyze` | 12 `avoid_print` infos, **all** in the untracked `audit_evidence/` probes; `lib/` and `test/` clean. Fixed by excluding `audit_evidence/**` in `analysis_options.yaml` (then: no issues) |
| `flutter test --coverage` | 909 passed, 51 skipped (rules tests need emulators), 0 failed |
| Rules tests (`firebase emulators:exec … flutter test test/rules`) | 51 passed, 0 failed |
| Builds | Debug and release APK built in the audit session (no code changed since); not repeated |
| Pre-existing failures | none |

## Owner decisions applied (remediation brief)
- DT-001 skipped: public sign-up is intentional. DT-005 skipped: backups are owner-managed.
- No push, no rules deployment, no billing/App Check changes. Local commits on `dev` only.
- The live probe of 8 Nov (11 throw-away accounts, 41 products) was cleaned up; the live project holds no test data.

## Issue inventory
DT-002 … DT-004, DT-006 … DT-024 are in scope (order per the brief). DT-001 and DT-005: excluded by owner.
