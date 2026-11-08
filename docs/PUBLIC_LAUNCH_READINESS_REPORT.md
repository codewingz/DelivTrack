# DelivTrack — Public launch readiness report

Date: 8 Nov 2026. Branch `dev`, 24 local commits ahead of `origin/dev` (head: the commit that adds this report; remediation head was `df54017`). `main` is 0 commits ahead of `dev`, so a later merge can be a fast-forward.
(Correction: my earlier hand-over said "28 commits"; the real number since the audit baseline `ebf1a5b` is 24.)
Nothing here was pushed, merged, deployed or changed in Firebase. Facts below were read-only checks unless marked otherwise.

## 0. Decision in one paragraph
**READY WITH CONDITIONS, but only in this order:** deploy the new rules and ship the new build together; decide abuse protection for open sign-up before the public hears about the app; run the physical-phone checklist; then merge. No unresolved defect lets one user read or change another user's data. The remaining risks are (a) project-wide quota exhaustion by a hostile sign-up, (b) unverified phone behaviour (reminders, offline), (c) a CI workflow that has never run, and (d) rules that cannot check item-line arithmetic, which only affects a user's *own* books.

---

## 1. The nine partially fixed issues: which ones can hurt public users?

| ID | What is left | Can it hurt **other** users? | Real risk for the public | Verdict |
|---|---|---|---|---|
| DT-002 | Rules cannot verify `lineTotal = quantity × price` or `expected = Σ lines` (1,000-expression limit per rule evaluation). A *modified* client can write inconsistent line totals into **its own** parcels. Received money can no longer move without a payment document. | No | A tampered client damages only its own accounting. Normal users go through the app's validated maths (tested). | **Low** (accept; a server check would need the Blaze plan) |
| DT-004 | Repository tests run on an emulator, not in the coverage number; CI never ran; offline behaviour untested | No | Process risk: a future change could regress money logic if CI is never activated | **Medium (process)** — fix by activating CI (section 3) |
| DT-006 | Uniqueness of a postal reference for "Other" services is app-enforced (guard id contains a URL-encoded free-text name that rules cannot rebuild). VPP/VPL/VPR are rule-enforced. | No | A tampered client could duplicate a reference inside its own account | **Low** |
| DT-007 | Audit entries must match a real simultaneous edit, but can still be omitted | No | Own audit trail incomplete only if the user's own client is modified | **Low** |
| DT-012 | Whole parcel list loaded; payments cached per session; 600-parcel measurement only; read billing not measured | Indirectly: reads/writes share one **project-wide** quota | A very active account costs more reads; rules now add lookups that Firebase bills as reads (section 5) | **Medium (cost/quota)** |
| DT-013 | Reminders are scheduled while the app is open; no phone notification for a date set after 9:00 AM; force-stop/battery managers; nothing proven on a phone | No | The feature users notice most; silent misses damage trust | **Medium** — run checklist 1-15 |
| DT-014 | Previous account's cache stays in the app's private storage after logout | No (path-scoped queries + rules; tested) | Only on a shared, rooted or forensically examined phone | **Low** |
| DT-015 | App enforces 8+ characters with letters and numbers; the server still accepts 6 if the API is called directly; no email verification | No | A direct-API account with a weak password is its own owner's problem; email squatting is possible (reset mail still goes to the real mailbox owner) | **Low–Medium**; console policy recommended |
| DT-021 | Upstream Kotlin-plugin warning; licences not accepted; two adb installs | No | None for users | **None** (developer machine) |

Highest-impact item that is *not* a code finding: **quota exhaustion through open sign-up** (section 5).

---

## 2. Safe deployment plan (rules + Android app)

### 2.1 Facts
- **Deployed rules today = the audit baseline** (ruleset `9064e494-21ee-48ab-a1f7-11b071194d75`, created 7 Nov 2026 20:50 UTC, 312 lines; byte-identical to `firestore.rules` at commit `ebf1a5b`). Local `firestore.rules` is now 437 lines. Read-only check.
- **The live database is empty** (`users` collection has no documents; the only data I created on 8 Nov was deleted). So no migration is needed and no real user data is at risk from the rule change.
- No app has been published (versions are `1.0.0+1`; AGENTS.md describes a pre-launch project). **Unknown to me:** whether any older APK is installed outside the owner's own test phones. Please confirm.

### 2.2 Compatibility between app and rules versions
| Combination | Result |
|---|---|
| **New app + old (deployed) rules** | Breaks: creating a parcel writes `postalGuardId`, a payment/correction writes `lastPaymentId`, a correction writes `correctedBy`, a review writes new fields; the old rules' `hasOnly` lists reject all of them |
| **Old app + new rules** | Breaks: new rules require the guard pointer on create, the payment pointer on payment, valid audit field lists (return) and `rev_` pointers on corrections. Reading, notes, Pay Later date edits, archive/restore of eligible parcels, customers and products still work |
| **New app + new rules** | Verified: 80 rules tests, emulator repository suites (auth 8, parcels 38, customers 7, products 10 runner totals), widget tests |
| **Existing documents (legacy, written before the change)** | Compatible by design and tested: no `lastPaymentId`/`postalGuardId` needed to read or edit; a legacy parcel can still be edited, paid, corrected (the pointer is added on first payment/correction), and its reference changed (old guard released). Not applicable today anyway (database empty) |

There is **no overlap window** in which old and new builds both work. That is acceptable only because nobody public has the old build. Making rules accept both would be a new architecture/rules-design effort and is **not recommended**; for future releases keep rule changes additive (accept old and new shapes first, tighten later).

### 2.3 Recommended sequence (each step has an owner and a stop condition)
1. **Freeze.** Tag the commit to ship (after your approval). Run on a clean checkout: `dart format --output=none --set-exit-if-changed lib test test_emulator`, `flutter analyze`, `flutter test`, `firebase emulators:exec … "flutter test test/rules"`, the emulator suite (`sh test_emulator/run.sh <id>`), `flutter build appbundle --release` (signing key required). **Stop** on any failure.
2. **Record the rollback target.** Save the current ruleset (`9064e494…`; also `git show ebf1a5b:firestore.rules`).
3. **Deploy the rules to production** from the frozen commit: `firebase deploy --only firestore:rules --project delivtrack-codewingz`, then confirm deployed == local (fetch the release ruleset and diff it, as done in this review). Only after the emulator rules tests pass. Any phone still running an old build stops working for parcel creation and payments from this moment.
4. **Smoke test on production** with the signed release build on a real phone and a throwaway account (checklist item 16), then delete the throwaway data and account. **Stop** if any step is refused: the likely cause is a rules/app mismatch or the rule-evaluation limit; fix in code, redo from step 1.
5. **Publish in stages** in Google Play: internal testing → closed testing → production with a staged rollout (for example 10 %, then 50 %, then 100 %), watching the Firebase usage page and Play vitals between stages.
6. **Rollback.** Halt the Play rollout. Redeploying the old rules is only safe if **no** user is on the new build (they would be locked out of creating parcels and payments); with an empty database and a staged rollout this is a decision for the owner at that moment. Prefer a fixed forward release.
7. **Merge `dev` → `main`, then push**, only after steps 1–4 pass and you approve. Pushing activates CI (it triggers on push to `dev`/`main`).

### 2.4 Release-build requirements
`flutter build appbundle --release` needs `android/key.properties` (upload keystore outside the repo). The build now fails clearly without it. Raise `version:` in `pubspec.yaml` (`1.0.0+1`) for every upload; Play rejects a repeated version code. Keep the keystore backed up by the owner (losing it blocks updates unless Play App Signing recovery applies).

---

## 3. CI workflow review (`.github/workflows/ci.yml`)

**Checked here:** YAML parses; jobs `checks`, `rules`, `repository`, `build`; every command is one that passes locally on macOS with the same Flutter (3.47.8) and firebase-tools (15.4.0, pinned); permissions are `contents: read`; no secrets used; `google-services.json` and `firebase_options.dart` (public client config) are tracked so the build needs none; the workflow is **not active** until pushed.

**Cannot be tested until it runs on GitHub (expect the first run to need fixes):**
1. That the pinned action major tags resolve as written (`checkout@v4`, `setup-java@v4`, `setup-node@v4`, `upload-artifact@v4`, `subosito/flutter-action@v2`, `reactivecircus/android-emulator-runner@v2`). Recommended before activation: pin each to a full commit SHA (supply-chain hygiene).
2. That `flutter-action` can install exactly Flutter 3.47.8 and cache it.
3. The `repository` job: KVM enablement on the runner, boot of an API 34 x86_64 `google_apis` emulator image, boot/run time versus the 45-minute limit, flakiness, and that `adb devices | awk 'NR==2 {print $1}'` yields the emulator id. This is the most likely job to fail first.
4. Downloading the Firestore/Auth emulator jars and Java 21 availability for `firebase emulators:exec`.
5. `dart format` output being identical on Linux; line endings.
6. Branch-protection integration (required checks) — a GitHub setting.
7. Duration and free-minute cost on GitHub (private repositories have monthly limits).

**Behaviour to know:** a `push` to `dev` or `main` runs all four jobs; `pull_request` runs them too.

---

## 4. Physical Android checklist review (`docs/MANUAL_DEVICE_CHECKLIST.md`)

It had 15 items (reminders, offline) — good for notifications but silent on sign-up, release build, accessibility, networks and performance. I **added items 16–26** (documentation only): release-APK smoke test on production with a throwaway account; sign-up/login/reset email and two accounts on one phone; Wi-Fi↔mobile switching; largest text/display size; TalkBack; back gesture/button; small screens + keyboard; notification permission by Android version; many parcels on a mid-range phone (on a test project, not production); App Check behaviour (if enabled); first-days quota watch.
**Everything in the checklist is currently NOT VERIFIED — PHYSICAL DEVICE REQUIRED.** Minimum before launch: items 1–10, 15, 16, 17, 19, 21. Record phone model and Android version for each run.
Gaps that remain even with the checklist: iOS (not a target), tablets/foldables (layout tested in widget tests only), very old Android versions (minSdk 24 is declared; not tried below the emulator's version).

---

## 5. Public sign-up security review (registration stays open)

**Live evidence (8 Nov, throwaway accounts, all deleted):** sign-up with only the public client config succeeds; a 6-character password was accepted by the server; 8 sign-ups in ~15 s all succeeded (no throttling seen); the email-existence lookup (`createAuthUri`) answered for any email; one stranger account wrote 41 valid documents into its own tree; **no** cross-account read or write succeeded, no write outside `users/{own uid}`, no unknown collection, no malformed document.

**What protects other users today:** per-user rules (`request.auth.uid == uid`), default deny, shape and size limits on every document (text lengths, ≤20 item lines, bounded numbers), append-only payments, no deletes.

**What does not exist:** App Check, any cap on documents per account, rate limiting, email verification, enforced server password policy, email-enumeration protection.

**Quota arithmetic.** The free (Spark) plan has project-wide daily limits (Firebase publishes 50,000 reads, 20,000 writes, 20,000 deletes per day; re-check the pricing page). A single script making valid writes from one throwaway account can reach 20,000 writes in minutes and stop the app for **all** users until the quota resets. Firebase's pricing page also states that reads made by security rules (`get`, `exists`, `getAfter`) are **billed as additional document reads**, even when the request is denied. The new rules add lookups per write (customer record on parcel create/change, reference guard, payment existence, audit target and so on; a small number each, deduplicated per request). I did not measure the extra reads in production; on the emulator billing cannot be observed. Expect roughly a few extra reads per write and budget for it.

**Options that keep registration open (owner choices, none applied):**
1. **App Check with Play Integrity**, enforced for Firestore and Auth, so only the genuine app from Google Play can call the project (debug builds need registered debug tokens). Strongest control; some friction for sideloaded installs.
2. **Budget alerts and a billing plan** (Blaze) so an attack costs money instead of stopping the app; paid service, needs your approval and a payment method.
3. **Console settings:** enforce a password policy (min 8, letters + numbers); turn on email-enumeration protection; review Auth quotas/blocking.
4. **Monitoring:** daily look at the Firebase usage page for the first weeks; alert thresholds in Google Cloud.
5. **Later, architecture (not done):** a per-account document cap via counters or Cloud Functions; email verification before writes.

---

## 6. Open financial, payment and isolation risks

**Closed and verified:** cross-user isolation (80 rules tests with two real users; emulator account-switching, denied cross-user writes with a clear message); money moves only with a new payment document in the same commit; payment status derived from amounts; expected amount cannot change alone; no overpayment; Gift/Free expects nothing; concurrent creation (5 parallel saves → 5 numbers) and payments (overlap handled, nothing lost); corrections keep the original, reverse and re-record (amount, date or both); returned parcels keep money and a flagged balance until a review is completed with reason and note; archiving keeps money in lifetime totals; damaged documents no longer blank the app; audit entries cannot claim a change that did not happen.

**Still open (honest list):**
1. Line arithmetic and `expected = Σ lines` — app-enforced only (DT-002). Own data only.
2. The payment ledger is self-reported by the user's device; there is no bank reconciliation, by design.
3. Audit entries can be omitted by a modified client (DT-007); "Other" service names (DT-006).
4. **Rule-evaluation headroom:** Firestore stops a rule after 1,000 expressions; I hit that limit twice and trimmed clauses. Every tested path passes, but a future rule addition can silently push some combination over the limit. The rules tests are the guard — keep them in CI, and treat any new rule clause as needing a budget check.
5. **Rule lookups cost reads** (section 5) — unmeasured.
6. Offline saves: the claim "fails clearly, no duplicate" is untested on a real offline device (checklist 15).
7. Cached documents of a previous account stay on the phone (DT-014).
8. Totals are computed on the device from the loaded list; a damaged document is excluded and flagged on the dashboard until repaired in the console.
No unresolved issue lets one user affect another user's money or data.

---

## 7. Git status check

- Branch `dev`; 24 commits ahead of `origin/dev`, 0 behind; `main` is not ahead of `dev`.
- Working tree: only `DELIVTRACK_FULL_AUDIT_REPORT.md` and `audit_evidence/` are untracked (kept, as instructed); this report and the checklist update are the only new edits.
- Deleted since the baseline: nothing of value. One rename (`lib/screens/splash_screen.dart` → `lib/features/auth/views/splash_screen.dart`). The `dio` and `cupertino_icons` dependencies were removed (unused). `integration_test/`/`test_driver/` were already deleted by you before this work.
- Removed today (regenerable, git-ignored, untracked, not referenced by any script): `coverage/` and `build/`. `firebase-debug.log` was already absent. `audit_evidence/`, the audit report, `DelivTrack_Demo_Ready.html`, `docs/audit_fixes/` and all other docs are present.
- No secrets in the ~21,700 lines added since the baseline; no keystore or `key.properties` tracked.

---

## 8. Required tests before launch (consolidated)
| # | Test | Where | Status |
|---|---|---|---|
| 1 | Full local suite on the frozen commit (format, analyze, unit/widget, rules, emulator repositories, release build) | Mac | Passed on 8 Nov; repeat at freeze |
| 2 | CI first run (all four jobs) | GitHub | **Not run** |
| 3 | Rules deployed == local; smoke test with the release build on production (checklist 16) | Production | **Not done (needs approval to deploy)** |
| 4 | Reminders and offline checklist 1–15 | Physical phone | **Not done** |
| 5 | Launch additions 17–25 | Physical phone | **Not done** |
| 6 | First-week quota and crash monitoring | Firebase console / Play | Not started |

## 9. Owner actions (exact)
1. Answer: is any older DelivTrack APK installed anywhere besides your test phones? (Decides whether a no-overlap rollout is acceptable.)
2. Decide on abuse protection for open sign-up (section 5) and apply it in the Firebase console yourself, or approve me to prepare the steps; no paid service was enabled.
3. Set the Firebase console password policy and email-enumeration protection (approval needed because it changes production settings).
4. Approve (or not) activating CI by pushing; consider pinning actions to SHAs first.
5. Approve deploying the new rules to `delivtrack-codewingz` at the moment of the release, and the release build/rollout plan in section 2.3.
6. Run the physical checklist on at least one real phone.
7. Accept the Android SDK licences and remove the duplicate `adb`.
8. Keep backups under your own management (backup work excluded) and keep the upload keystore backed up.
9. Approve the merge to `main` only after the steps above.

## 10. Recommended release sequence (summary)
Decisions (1–5 above) → freeze commit and run the full local suite → record rollback target → deploy rules → release-build smoke test on production with a throwaway account (then delete it) → physical checklist → push `dev` (CI runs; fix if needed) → merge to `main` → Play internal → closed → staged production → daily quota/crash watch for two weeks.
