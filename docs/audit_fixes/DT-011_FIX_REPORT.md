# DT-011 — Payment review could never be completed (MEDIUM)

**Status: FIXED AND VERIFIED**

## Before the fix
A returned parcel with `paymentReviewRequired = true` had no way to leave that state; the Review tab, the dashboard card and the report row kept it forever (until DT-003/archiving, which is now blocked while a review is open).

## Design (owner brief)
"Mark Review Completed" records the decision only. It never refunds, adjusts or deletes anything:
- New optional parcel fields: `paymentReviewReason` (`refund_given | money_kept | balance_waived | other`), `paymentReviewNote` (required, 5-200 chars), `paymentReviewDateLocal` (yyyy-MM-dd, between the returned date and today, Pakistan time), `paymentReviewResolvedAt` (server time).
- Completing sets `paymentReviewRequired` to `false`, so the parcel leaves the Review tab, dashboard count and report urgency automatically (they all read that flag) and becomes archivable (DT-003). Payments, `receivedPaisa`, `outstandingPaisa` and statuses are untouched.
- Audit entry `resolve_review` (rules enum extended) with the changed fields.

## Changes
- `firestore.rules`: new fields allowed in the shape; a returned parcel may take one extra kind of update — a review completion that changes **only** those five fields plus `updatedAt`, only while `paymentReviewRequired == true` and no resolution exists yet, with `paymentReviewResolvedAt == request.time`; `validReturnFields` accepts review=false only together with a valid resolution (reason in the list, trimmed note 5-200, valid date within range) and only when money is involved; the fields cannot exist on a non-returned parcel; audit action `resolve_review` allowed.
- `ReviewResolution` enum (`parcel_enums.dart`); `Parcel.reviewResolution/reviewNote/reviewDate` + `paymentReviewCompleted`.
- `ParcelRepository.completePaymentReview` (interface, Firestore transaction: parcel exists, not archived, review open, date not before the returned date or in the future, note 5-200), fake repository.
- `showReviewSheet` in `parcel_action_sheets.dart` (reuses `showFormSheet`/`AppFormSheet`, `AppChoiceField`, `AppDateField`, `AppTextField.multiline`, so no new widget); button "Mark Review Completed" in Actions; Return section shows "Completed on <date>: <reason>" and the note.

## Tests (all run)
- Rules (emulator): 6 new tests — valid completion for all four reasons; reason/note/date/server-time validation; only review fields change and only once (no re-open, no rewrite, no money/notes riding along); not on a sent parcel or a Gift/Free return; archive and notes work afterwards, another user denied, archived parcel cannot be completed. `firebase emulators:exec … "flutter test test/rules"` → **64 passed**.
- Widget/domain: button offered only for an open review; reason and note required (empty / too short); success path shows the decision, keeps the money, offers Archive; repository failure shown; fake-repository flow makes the parcel archivable.
- Real `FirestoreParcelRepository` on the Android emulator (historic suite run temporarily + new test): **30 passed** — short note and future date refused, completion recorded, money and payment history unchanged, second completion refused, archive works, another user refused.
- `flutter analyze`: no issues. `flutter test`: all passed (see final report for counts).

## Regression
Return flow, Review tab filter (`payment_tabs`), dashboard stats, reports, archive/restore all still pass.

## Remaining risk
Reasons are a fixed list (`other` + note covers the rest). Reports still list a completed returned parcel under "Returned parcels" (without the urgent mark).
