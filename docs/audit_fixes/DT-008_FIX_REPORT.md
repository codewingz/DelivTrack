# DT-008 — A payment's received date could not be corrected (MEDIUM)

**Status: FIXED AND VERIFIED**

## Before the fix
`correctPayment` accepted only an amount and a reason; both the reversal and the replacement were stamped with a **new** server time, so any correction moved the payment to "today", and a wrong date could never be fixed. A correction to the same amount was refused outright.

## Changes
- `ParcelRepository.correctPayment(..., {String? receivedOn})`:
  - the replacement **keeps the original payment's day** unless `receivedOn` names a new one (so amount-only corrections no longer change the date);
  - a **date-only** correction (same amount, new day) is allowed; "nothing changes" is refused;
  - validated: valid date, not in the future, not before the sending date (Pakistan dates); a reason of 5-200 characters is still required;
  - new day = server time if it is today, otherwise noon Pakistan time of that day (same convention as `recordPayment`);
  - the reversal records who made the correction (`correctedBy` = uid) and when (`recordedAt`, server time); the original payment and the reversal stay in the history.
- `firestore.rules`:
  - the replacement's `receivedAt` may be `request.time` or an earlier moment whose Pakistan day is not before the sending date (same bounds as a late payment);
  - the parcel's `lastPaymentId` may change to a new payment document **without moving money** (needed for date-only corrections); an unchanged pointer must go with unchanged money, a changed pointer must name a payment created in the same commit (DT-002 stays intact);
  - `correctedBy` allowed on the reversal and must equal the signed-in uid.
- UI: the Correct payment sheet has a "Received on" field (pre-filled with the payment's day, bounded by the sending date and today); "Change the amount or the date" replaces "Enter a different amount".
- Reports/filters already use the non-reversed positive payments' `receivedAt`, so the corrected day is the effective payment date (verified, see below).

## Tests
- Rules (emulator): 6 new tests in "date corrections (DT-008)" — date-only correction accepted with the original, reversal and replacement kept; future and before-sending days refused; reason required and money must not move; `correctedBy` cannot be faked; another user refused; a pointer change without a new payment refused. **78 passed** in total.
- Widget: sheet shows the original day, amount-only correction sends no new date; date-only correction needs a new day and a reason, keeps the amount and the original/reversal/replacement in the history and does not move money.
- Real repository on the Android emulator (parcel backdated 3 days with the admin token): nothing-changes, future, before-sending and short-reason corrections refused; date-only correction to 2 days ago → replacement on that Pakistan day, original and reversal kept, received unchanged, `paymentDates` returns the corrected day; a following amount-only correction keeps that day; another user refused. Suite: **34 passed**.
- `flutter analyze` clean; `flutter test` all passed.

## Regression
All earlier payment, correction, return and archive tests (rules, widget, repository) pass.

## Remaining risk
`correctedBy` is always the owner's own uid (single actor per account) — recorded, not independently verifiable. The correction keeps no separate "date before" field: the original document is the record of the earlier date. Deploy rules with the app build.
