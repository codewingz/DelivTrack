# DT-024 — Requirements and plan disagreed on the account model (LOW)

**Status: FIXED AND VERIFIED** (documentation; the Sign Up screen and per-user implementation are unchanged)

## Owner decision applied
DelivTrack is a **public multi-user** Android app with open registration; each account has private data and its own order sequence. DT-005 (backups) stays owner-managed and is not touched.

## Documents changed
- `DelivTrack_Project_Requirements.md` → **v1.3** (8 Nov 2026): a prominent "v1.3 account model" note; scope 1.2 (public sign-up now in scope; the business's own customers never log in); FR-14 renamed "Account access and cloud backup" (public sign-up, one private account per user, no staff roles/sharing); Login row → Login / Sign up / password reset; WF-01 first step; data model (`app_settings/main` → all collections under `users/{uid}/…`, counter at `users/{uid}/counters/orders`); services table and 8.2 (Auth with public sign-up, rules by `request.auth.uid == uid`); security items 1, 2, 9; build order step 2; out-of-scope item on roles/accounts reworded.
- `docs/DelivTrack_Development_Plan.md`: order-number counter (§2.3, data table) per account; D1 text; new section **"Account model and quotas"** (public multi-user model and how it is verified; shared Firebase free-plan quotas with the caveat to check the current published figures; mitigations that need the owner: App Check, billing alerts, console password policy; backups owner-managed; reminder and Android architecture pointers).
- `docs/REQUIREMENTS_TRACEABILITY.md`: the D1 sentence now cites the v1.3 decision and its tests.

## Checks
- `grep` for "no public sign-up", "one private company", "one approved", "pre-provision", "single account", `app_settings` in the requirements and plan: the only remaining hits are the v1.3 note itself and the plan's D1/§2.3 history notes that explain what changed.
- Implementation matches the documents: Sign Up screen and `FirebaseAuthRepository.signUp` exist; rules are per-user with default deny (80 rules tests, two users); emulator tests: two independent users register, the second sees nothing of the first, starts at `ADT-000001`, and may reuse the same postal reference; `AGENTS.md` already described the per-user model.
- Not claimed: the quota figures are those Firebase publishes and were not re-checked against the live pricing page in this run.
