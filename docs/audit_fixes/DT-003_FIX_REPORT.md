# DT-003 — Returned parcel with an open payment review could be archived (HIGH)

**Status: FIXED AND VERIFIED** (the way to *complete* a review is DT-011, next).

## Before the fix
Rules allowed archiving any `returned` parcel; `Parcel.canArchive` treated "returned" as nothing left to chase; the existing rules test archived a review-flagged returned parcel and expected 200. After archiving, `watchAll` excludes the parcel, so it left the lists, the Review tab and the dashboard. Evidence: the old assertion at `firestore_rules_test.dart` ("returned" → 200) and audit section 11, DT-003.

## Changes
- `firestore.rules`: archiving needs `paymentReviewRequired` to be absent/false in addition to the existing conditions.
- `Parcel.canArchive` (`parcel.dart`): `!paymentReviewRequired &&` the previous condition. The details screen already hides the Archive button from it.
- `FirestoreParcelRepository._setArchived`: refuses with "A parcel can't be archived until its payment review is completed." (transaction, before the write).
- `parcel_details_screen.dart`: an info row "This parcel can't be archived until its payment review is completed." in the Actions section while a review is open.
- Tests: `firestore_rules_test.dart` (returned + open review → 403; review flag cannot be dropped while archiving; returned Gift/Free with no review → 200), `archived_parcels_test.dart` (domain rule; fake repository refuses; parcel and its money stay in `watchAll`), `parcel_details_test.dart` (no Archive button, message shown).

## Verification (commands and results)
- Tests written first; 3 failed before the fix (button visible, rules 200, domain true).
- `flutter analyze` → no issues. `flutter test` → 911 passed, 58 skipped (rules). Rules via `firebase emulators:exec … "flutter test test/rules"` → 58 passed.
- Real `FirestoreParcelRepository` on the Android emulator against the emulators (historic suite, run temporarily; the archive test was updated to expect the refusal for a flagged returned parcel and success for a returned Gift / Free parcel) → 29 passed.
- Cross-user: existing "another user cannot archive or restore" still passes.

## Regression
Draft, paid-in-full and Gift / Free archive, restore, and the archived list all still pass (rules + widget + repository tests). Payment history is untouched.

## Remaining risk
A flagged parcel cannot be archived until DT-011 adds "Mark Review Completed"; until then such parcels simply stay in the Review list (intended).
