# DT-006 — Postal-reference uniqueness was enforced only by the app (MEDIUM)

**Status: PARTIALLY FIXED** — fully enforced by the rules for VPP / VPL / VPR; for "Other" services the rules require a guard linked to the parcel but cannot verify the free-text service-name part of the guard id.

## Before the fix
Probe P3 (audit): a guard was created, deleted, and a second parcel with the identical reference was created with no guard — all HTTP 200. Guards had a shape check only and the owner could delete them at any time.

## Design
- New optional parcel field `postalGuardId` = id of the guard document `postal_refs/{id}` that reserves the parcel's (service, reference). The app already used `Service__Reference` (URL-encoded) ids.
- Create: a parcel with a reference must carry `postalGuardId`; the guard must be created in the **same commit** (`existsAfter`, `!exists`) and point back at the parcel. For VPP/VPL/VPR the id must equal `service__reference` with `/` written `%2F` (derived in the rules, so a duplicate can only use the existing guard id, which belongs to the first parcel → refused). A parcel without a reference must not carry the field.
- Update: unchanged reference → the pointer must not change (so records created before this change, which have no pointer, stay editable); changed reference → a new guard is created in the same commit and the pointer follows; cleared → no pointer.
- Guard rules: create only together with the parcel that points at it; no rewrite; **delete only in the commit that moves that parcel to another reference** (or clears it).
- The repository stores `postalGuardId` on create and when a reference changes (it already deleted the old guard and created the new one in the same transaction).

## Changes
`firestore.rules` (guard functions `guardOk`, `sameReference`, guard match rules; budget trimming: the customer snapshot's text checks are now implied by `customerMatches`), `parcel_repository.dart` (`_newParcelFields`, `update`), `test/rules/*` (fixtures create guards; `DocWrite.delete`; new group of 9 tests; the old "owner can delete a guard" test was replaced by the new semantics).

## Tests
- Rules, emulator: **72 passed** (incl. 9 new): same-user duplicate (no guard / existing guard / made-up id) denied; slash references use the `%2F` id; different users same reference allowed; four simultaneous saves of one reference → exactly one succeeds; lone guard create/rewrite/delete denied, other user denied; legitimate reference change with release of the old guard; stale guard cannot be removed alone; pointer cannot move without a new reference; draft has no guard; legacy record (created with the emulator admin token, no pointer) still readable and editable and can move to a new reference; "Other" service requires a linked guard of the right shape.
- Mutation check: removing the create-time guard requirement fails 3 of the DT-006 tests.
- Real repository on the Android emulator (historic suite + new test): **31 passed** — 3 parallel saves of one reference → exactly one parcel, normalised duplicate refused, moving the reference frees the old one and reserves the new one; all earlier tests (order numbers, 5 parallel creates, edits, payments, etc.) still pass.
- `flutter analyze` clean; `flutter test` 916 passed (72 rules tests skipped without emulators).

## Discovered constraint
Firestore evaluates at most 1,000 expressions per rule evaluation; adding the guard check pushed `update` over the limit, so the redundant snapshot text checks were removed (equal in effect because the snapshot must equal the validated customer record).

## Remaining risks
1. "Other" services: the guard id contains the URL-encoded, lower-cased, collapsed service name; rules cannot rebuild it, so a modified client could choose a different name part and reserve the same reference twice. Uniqueness there stays app-enforced.
2. A stale guard (left when a client changes a reference without deleting the old guard) keeps the old reference reserved; the app always deletes it in the same transaction.
3. Deploy rules together with the new app build (old builds do not write `postalGuardId`).
