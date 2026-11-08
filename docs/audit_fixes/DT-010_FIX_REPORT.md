# DT-010 — Archiving silently lowered "Total received" and the payment history (MEDIUM)

**Status: FIXED AND VERIFIED**

## Before the fix
`watchAll` excluded archived parcels and fed every figure: the dashboard's "Total received" and "Advance amount", the Payments tab's "Advance received", the customer's "Advance received" and the payment-received history report. Archiving a fully paid parcel therefore reduced those money figures with no ledger change.

## Rule adopted (owner brief)
Archiving is organisational, not a financial event. **Money received stays in the lifetime figures; counts, lists, balances and reminders cover active parcels only.** An archived parcel owes nothing (the rules only allow archiving when nothing is left to collect and no review is open), so balances are unaffected.

## Changes
- `ParcelRepository.watchAll({bool includeArchived = false})` (Firestore + fake).
- `DashboardStats.from`: received and advance are summed over every parcel; every count, the recent list, outstanding / Pay Later balances, review and reminders use active parcels only. The dashboard (via `ReminderListViewModel(includeArchived: true)`, whose reminders still use active parcels) and a caption under the figures say so.
- `PaymentsViewModel`: totals over every parcel; tab lists show active parcels only.
- Customer details: "Advance received" is lifetime (includes archived); the "Parcels" count, the Pay Later reminders and the parcel history list are active parcels only.
- Payment received history (`ReportViewModel(includeArchived: type.needsPayments)`): includes the payments of archived parcels; the other reports stay on active parcels.
- Customers list figures (parcel count, outstanding) deliberately unchanged: archived parcels have no balance.

## Tests
- New `test/archived_totals_test.dart` (7 tests): archive keeps Total received while counts drop; restore does not double count; two users' repositories never mix; payments-tab totals keep archived advance, lists exclude archived in every tab; payment history includes an archived parcel's payment and its total equals the ledger (Rs. 6,000); other reports stay active-only; customer details (lifetime advance Rs. 5,000, `Parcels: 1`, archived parcel not in the history). Mutation check (received over active parcels only) fails 2 of them.
- Real repository on the Android emulator: archived paid parcel remains in `watchAll(includeArchived: true)`, absent from `watchAll()`, payment history untouched, restore yields exactly one parcel with the same money. Suite: **33 passed**.
- `flutter analyze` clean; `flutter test` 941 passed.

## Regression
Dashboard, payments, reminders, reports, customers, archived list tests all pass unchanged; rules untouched (rules tests 72 pass, unaffected).

## Remaining risk
A parcel's money is still counted from its own `receivedPaisa`; that now moves only with a ledger entry (DT-002). "Parcels with payment received" is a count of active parcels by design and may differ from the money figure.
