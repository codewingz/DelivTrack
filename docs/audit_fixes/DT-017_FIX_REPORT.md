# DT-017 — Dart formatting not applied project-wide (LOW)

**Status: FIXED AND VERIFIED**

## Change (formatting only, one separate commit)
`dart format lib test test_emulator` with the default formatter (138 of 156 files changed). The formatter now writes `if (x)\n  statement;` on two lines, which the project's `curly_braces_in_flow_control_structures` lint rejects, so `dart fix --apply --code=curly_braces_in_flow_control_structures` added braces (141 places in 35 files; no behaviour change), then the files were formatted again. No application logic was edited in this commit.

## Verification
- `dart format --output=none --set-exit-if-changed lib test test_emulator` → exit 0 (nothing left to format).
- `flutter analyze` → no issues.
- `flutter test` → 951 passed, 80 skipped (rules tests). `firebase emulators:exec … "flutter test test/rules"` → all 80 passed.
- The emulator repository suite is re-run in the final verification.
- CI (`.github/workflows/ci.yml`) already runs the format check; it has not run on GitHub.

## Notes
`audit_evidence/` (audit probes) and `android/` are outside the formatted/checked set. A file added later must be formatted before commit (the CI step fails otherwise).
