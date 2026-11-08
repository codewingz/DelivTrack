# DT-022 — Genuine permission-denied errors were retried five times (LOW)

**Status: FIXED AND VERIFIED** (behaviour kept, made explicit and tested; no weaker safety)

## Analysis
`permission-denied` is how Firestore answers the loser of two overlapping writes on the mobile SDK (verified on the real backend earlier: 5 parallel saves all succeed within 5 attempts), so the retry cannot simply be removed. Firestore does not tell contention and a real rule denial apart. What the code can do is keep the retry bounded, fresh and limited to the operations that read state: create parcel, record payment, correct payment (the only three callers). Each retry re-reads in a new transaction, so an action the fresh state no longer allows (archived, returned, overpay) is refused by the app's own check at once with its own message instead of being retried.

## Change
`retryWhenDenied` moved from a private method to `lib/core/data/retry_when_denied.dart` (same behaviour: ≤ 5 attempts, 25 ms × n + up to 75 ms jitter, so a genuine denial is reported after about a second), with documentation, injectable pause/random for tests, and `FirestoreParcelRepository` calling it. Only `permission-denied` is retried; every other Firestore error is reported immediately; `AppFailure` passes through.

## Tests
- `test/retry_when_denied_test.dart` (7): first-try success, contention that clears, bounded exhaustion with the clear message and total pause under 1.2 s, no retry for `unavailable`/`deadline-exceeded`/`aborted`/`internal`, app refusal passes through, a retry that ends in the app's fresh-state refusal, configurable attempts.
- Emulator suite (real transactions): five simultaneous creations get five consecutive numbers, overlapping payments (last one refused, nothing lost), two corrections at once (one wins), a cross-user write is refused with a clear message in under 4 s, archived-parcel writes refused. Auth 8 / parcels 38 / customers 7 / products 10 — all passed; `flutter analyze` clean; `flutter test` all passed.
- Network failure: covered by "other errors are not retried" and the message mapping; real offline behaviour is still NOT VERIFIED (see DT-004).

## Remaining
A genuine denial still costs ~1 s before the message; reducing attempts would risk failing real concurrent saves.
