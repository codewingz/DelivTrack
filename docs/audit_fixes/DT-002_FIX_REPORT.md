# DT-002 — Financial data integrity (HIGH)

**Status: PARTIALLY FIXED** (money, status, customer snapshot and "expected amount changes only with the lines" are enforced by the rules; "expected = sum of the line totals" and "line total = quantity x price" cannot be enforced by Firestore rules, see Remaining risks).

## Original problem
The parcel `update` rule only checked the parcel's internal arithmetic, so the owner's client could set `receivedPaisa`/`paymentStatus` with no payment record, shrink `productAmountExpectedPaisa` while the lines stayed the same, and replace the customer snapshot with another person (audit probes P1, P2, P5 on the emulator: all HTTP 200).

## Investigation
Read `firestore.rules` (parcels, payments, audit), `ParcelRepository` (`create`, `update`, `recordPayment`, `correctPayment`), `payment_rules.dart` (`paymentStatusFor`), `parcel_input.dart` (`expectedPaisa`), `Parcel.fromMap`, the existing 51 rules tests and the (historic) repository tests. Unknown fields in `Parcel.fromMap` are ignored, so the new `lastPaymentId` field is backward compatible; older documents simply lack it.

## Root cause
Nothing linked a change of the parcel's received amount to a payment document. The payment rules checked the parcel (`getAfter`) but the parcel rule did not check the payment.

## Evidence before the fix
`audit_evidence/rules_probe_test.dart` P1, P2, P5 returned 200 (see audit report section 16.3).

## Changes
- `firestore.rules`
  - New optional parcel field `lastPaymentId` (pointer to the payment/reversal that last moved the money).
  - Parcel `update`: if `receivedPaisa` changes, `lastPaymentId` must change to a payment document that is **created in the same commit** (`existsAfter` and `!exists`); if the money does not move, `lastPaymentId` must not change. The existing payment rules already require the parcel to move by exactly that payment (and reversal + replacement for corrections), so the amounts are bound both ways. A payment id can never be reused (payments are create-only).
  - `paymentStatus` must equal the status derived from the amounts (`statusFor`, same logic as `paymentStatusFor`).
  - The expected amount can change only when the item lines or the collection method change in the same write.
  - Customer snapshot: on create it must equal the customer record (`customerMatches`, reads `customers/{customerId}`); on update it must be unchanged or a copy of the (new) customer's record.
  - `lastPaymentId` is rejected on create.
- `lib/features/parcels/data/parcel_repository.dart`: `recordPayment` writes `lastPaymentId` = the payment id; `correctPayment` writes the reversal id.
- `analysis_options.yaml`: excludes `audit_evidence/**` (probe files use `print`).
- `test/rules/firestore_rules_test.dart`: fixtures use a customer record and real payments; new group "financial integrity (DT-002)" (7 tests).

## Security implications
Cross-user isolation unchanged (rules still `isOwner(uid)`); another user is denied in the new tests. The change **tightens** rules; nothing was loosened. Public sign-up is unaffected.

## Tests
- Rules: 58 tests (51 existing, adapted to the stricter rules, + 7 new) — `firebase emulators:exec --only auth,firestore --project delivtrack-codewingz "flutter test test/rules"`: **58 passed**.
- Mutation check: removing the ledger clause makes 2 of the new tests fail (received money forged; pointer reuse), confirming they detect the defect.
- Real repository on the Android emulator (API 36, `emulator-5554`) against the Auth + Firestore emulators, using the historic `parcels_repository_test.dart` temporarily (not restored to the repo; customer fixture added): **29 passed**, including parallel payments, overlapping payments, corrections, return, archive, cross-user denial.
- `flutter analyze`: no issues. `flutter test`: 909 passed, 58 skipped (rules tests, need emulators), 0 failed.

## Required-test mapping
| Required test | Covered by |
|---|---|
| Direct received change without payment denied | "received money cannot be set…" |
| Valid payment allowed | existing "partial and final payment", repository test |
| Overpayment denied | existing rule test + repository test |
| Duplicate payment denied | "lastPaymentId can only name a new payment…" (id reuse; overwrite of a payment) |
| Partial payment | existing tests |
| Concurrent payments | repository tests (emulator) |
| Invalid product totals | **limited**, see below |
| Legitimate product edit | "expected amount… moves with the item lines" and "parcel edits" |
| Cross-user modification denied | "another user cannot change…" |
| Dashboard reconciles with ledger | received now moves only with a ledger entry; dashboard sums `receivedPaisa` (existing `dashboard_stats_test`) |

## Remaining risks (not falsely claimed as secured)
1. Firestore caps a rule evaluation at 1,000 expressions (observed: "maximum of 1000 expressions" with a 20-line sum). So rules **cannot** prove `expected = sum(lineTotals)` or `lineTotal = quantity x price`; a client that edits the lines can still write inconsistent line totals. These stay enforced by the app (`ParcelInput`) and its unit tests. Full enforcement needs a trusted backend (Cloud Function) — not added (needs Blaze, owner approval).
2. A client can still create a payment document and a parcel move that are consistent with each other but not real money (the ledger is self-reported by the owner's own device).
3. **Deployment order:** the new app writes `lastPaymentId`, which the currently deployed rules reject; the new rules reject old app builds that do not write it. Rules were **not deployed** (brief). Deploy rules and release the app together.

## Final status
PARTIALLY FIXED (items 1-2 above are inherent limits of rules-only enforcement).
