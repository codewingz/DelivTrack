# DT-014 — Local cache and privacy across sessions (LOW)

**Status: PARTIALLY FIXED** — account isolation is proven by tests; clearing the on-device cache at logout was researched and deliberately NOT added; data at rest on the phone remains.

## Research (accessed 8 Nov 2026)
- `cloud_firestore` 6.0.3 API docs in the pub cache (`firestore.dart`): `clearPersistence()` "is primarily intended to help write reliable tests… does not attempt to securely overwrite or otherwise make cached data unrecoverable. For applications that are sensitive to the disclosure of cached data in between user sessions, we strongly recommend not enabling persistence at all"; it fails while the instance is running; `terminate()` leaves only `clearPersistence()` usable.
- Web search "cloud_firestore flutter clearPersistence terminate sign out": FlutterFire issue [#17781](https://github.com/firebase/flutterfire/issues/17781) reports that using Firestore again after `terminate()` crashes ("The client has already been terminated", cached terminated instance); Firebase JS reference states the same ordering rule for `clearPersistence`. Nothing found that makes terminate + clear at logout a supported runtime step.
- Decision: **no `terminate()`/`clearPersistence()` at logout** (unsupported at runtime, known crash, and documented as not secure anyway). The only documented secure alternative is disabling persistence entirely, which would also remove offline reads and the "billed only for changed documents on reopen" saving (DT-012) — an owner decision, not made here.

## What protects a second account today (verified)
- Every query is scoped to `users/{currentUid}/…`; the rules deny any other path; screens, view models and the notification scheduler are rebuilt/cleared per session; sign-out cancels every scheduled notification (`reminders_notifications_test`, `session_switch_test`).
- New emulator test "account switching": A creates parcels, a payment and an archived draft, then B signs up on the same device — B's first emission of `watchAll` (possibly cache-served), `watchArchived`, `watchUnreadable` and `paymentsFor([A's parcel])` hold nothing of A's, B cannot write to A's parcel id, B's numbering starts at ADT-000001 and may reuse A's reference; A signs in again and sees only A's parcel and money. **38 parcels tests pass.**

## Not done / residual
- Cached documents of the previous account stay in the app's private storage on the phone (readable only with root/forensic access or backup, and `allowBackup=false`). A screen-capture block (`FLAG_SECURE`) was not added (needs owner approval).
- "Data remains isolated after app restart": not testable in this harness (no process restart); by design the isolation does not depend on the cache (queries are path-scoped and rules-checked).
- Logout notification cancel on a real phone: NOT VERIFIED — PHYSICAL DEVICE REQUIRED (checklist step 9).
