# DT-009 — One malformed document blanked every parcel screen (MEDIUM)

**Status: FIXED AND VERIFIED**

## Before the fix
`_watchParcels` built the whole list with `Parcel.fromMap`, which throws on a missing field, a wrong type or an unknown enum value (`parcel_enums.dart`). A throw inside the stream mapper put the stream in the error state, so Parcels, Payments, Dashboard, Reports and the customer figures all showed their error state. Payments had the same weakness (`_paymentFrom`). Evidence: `audit_evidence/fromMap_probe_test.dart` (missing `items` → `_TypeError`; `parcelStatus: 'on_hold'` → `StateError`).

## Changes
- `Parcel.tryFromMap` / `Parcel.readAll` (`parcel.dart`): a document is read or reported by id. It is **not** read when a field is missing, has the wrong type, an enum is unknown, money is negative or `outstanding != max(expected - received, 0)`. Nothing is defaulted or repaired, so an invalid amount never becomes a valid one. Only `TypeError` and `StateError` are caught (no broad catch).
- `FirestoreParcelRepository`: `watchAll` / `watchArchived` use `readAll`; new `ParcelRepository.watchUnreadable()` streams the ids of unreadable documents; `_paymentFrom` returns null for a damaged payment document, which is then skipped in `watchPayments` and `paymentsFor` (counts for nothing, never as money).
- Dashboard: `_UnreadableNotice` (own subscription, disposed with the widget) shows "N parcel(s) couldn't be read, so they are left out of the lists and totals (document ids…)" — ids only, never customer data; at most three ids + "and N more". Wraps at 2x text.
- Old documents (before review/archive/guard fields existed) read unchanged (tested).

## Tests
- `test/parcel_reading_test.dart` (new, 15 tests): three valid; two valid + one bad; 12 damage kinds (missing items, items not a list, unknown method/status/payment status, missing snapshot, missing money fields, money as text, fractional money, negative money, inconsistent outstanding, wrong-typed sequence) each excluded and reported without affecting the others; old-format document.
- `test/dashboard_screen_test.dart` (+3): no notice normally; one damaged parcel named by id while the others still count; five damaged → three ids + "2 more" at 360 px and 2x text without overflow.
- Real repository on the Android emulator (admin-token writes of a damaged parcel and a damaged payment): lists keep the 2 valid parcels, `watchUnreadable` reports the id, the damaged payment is skipped in `watchPayments` and `paymentsFor`. Whole suite: **32 passed**.
- `flutter analyze` clean; `flutter test` **934 passed**.
- A real bug found by the suite while doing this: a stored single-subscription stream broke on the dashboard's Retry rebuild; fixed by letting the notice own its subscription.

## Regression
Customers, reports, payments tabs and the dashboard figures use the same lists and pass their existing tests.

## Remaining risk
A damaged parcel is hidden from totals until repaired (stated on the dashboard). There is no in-app repair tool; the console is needed. Parcel *details* opened by id still use the strict reader (a damaged document shows the error state for that one screen only).
