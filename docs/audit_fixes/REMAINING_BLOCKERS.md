# Remaining blockers and owner actions (8 Nov 2026)

Nothing below can be closed by code alone. None was done by the agent: no Firebase console change, no billing, no deployment, no push.

## Must happen before the public release
1. **Deploy the new Firestore rules together with the new app build.** `firestore.rules` changed substantially (DT-002, 003, 006, 007, 008, 011) and the app now writes new fields (`lastPaymentId`, `postalGuardId`, review fields, `correctedBy`). The rules currently deployed to `delivtrack-codewingz` are the old ones: the new app would be refused by them, and old app builds are refused by the new rules. Deploy only after `firebase emulators:exec … "flutter test test/rules"` passes (80/80 today), compare deployed == local afterwards (`AGENTS.md`). Existing documents stay readable and editable (legacy-compatibility is tested).
2. **Abuse protection for the open sign-up (DT-001, accepted risk, owner-managed):** App Check (Play Integrity) enforcement, a billing plan with budget alerts, and a console password policy (min 8, letters + numbers) and email-enumeration protection. Without these, anyone can create accounts and consume the project-wide free quota.
3. **Real-phone check of reminders and offline behaviour** — `docs/MANUAL_DEVICE_CHECKLIST.md` (now 15 steps): delivery at ~9:00, app swiped away, restart, app update, battery saver, force-stop, logout, and an airplane-mode save. All **NOT VERIFIED — PHYSICAL DEVICE REQUIRED**.

## Owner decisions
- Keep the SDK-bundled `integration_test` **dev dependency** (needed by `test_emulator/`; removed earlier at your request).
- Activate CI: `.github/workflows/ci.yml` exists but has **never run**; it is not pushed.
- Plan D17 (a phone notification for a date set for today after 9:00) and background re-sync of reminders need new storage/infrastructure; not built.
- Whether to disable Firestore persistence (secure cache at logout, DT-014) at the cost of offline reads and extra reads.
- Optional: `FLAG_SECURE`, Crashlytics, Dart obfuscation, a Cloud Function to enforce totals/line prices and tamper-evident audit (needs the Blaze plan).
- Merge `dev` into `main` (not done).

## Machine/tooling (DT-021)
`flutter doctor --android-licenses` (accept licences yourself); remove one of the two `adb` installs. The Kotlin-plugin warning from `firebase_auth`/`firebase_core` is upstream.

## Limits of what was proved
- Firestore rules cannot sum 20 item lines or multiply quantity × price (1,000-expression limit per evaluation): those stay app-enforced (DT-002). An edited client can still write inconsistent line totals into **its own** parcels; it cannot move received money without a payment record, change another user's data, or forge an audit entry for a change that did not happen.
- Audit entries cannot be forced to exist for every edit without a server (DT-007); "Other" postal service names cannot be verified by rules (DT-006).
- Performance was measured with 600 parcels only (DT-012); 1,000 / 10,000 not run; read billing not measured.
- Offline transactions: the one emulator probe (`disableNetwork`) did not simulate offline; only message mapping is unit-tested (DT-004).
- Cached documents of a previous account stay in the app's private storage after logout (DT-014).
