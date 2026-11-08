# DT-007 — The audit log could be forged (MEDIUM)

**Status: PARTIALLY FIXED** — entries must now describe a real edit written in the same commit; the app still writes them itself, so "every edit has an entry" cannot be enforced without a trusted server.

## Before the fix
The audit-log rule checked only the entry's shape (probe P4: an entry for a change that never happened → HTTP 200). Entries could not be updated or deleted, but nothing tied them to a real change; the order number was optional.

## Changes (`firestore.rules`, `parcel_repository.dart`)
`auditMatchesEdit(uid, entry)` — an entry is accepted only if, in the same commit:
- the parcel it names exists and is **written in this commit** (`getAfter(parcel).updatedAt == request.time`);
- `orderNumber` is required and equals that parcel's order number;
- **every field in `changedFields` really changed** (`changedFields ⊆ getAfter(parcel).diff(get(parcel)).affectedKeys()`), so an entry cannot claim an edit that did not happen;
- the **action matches**: `archive` (not archived → archived), `restore` (reverse), `return` (sent → returned), `resolve_review` (resolution newly present), `correct_payment` (the parcel's payment pointer moves to a new `rev_…` document); `update` for other edits.
Entries stay create-only (no update, no delete) and readable only by their owner. `createdAt` must still be server time.
Repository: the audit field lists now contain only fields that really changed (return: `returnReason` only when given; payment correction: `lastPaymentId` plus the money fields that actually moved, so a date-only correction logs only the pointer).

## Tests
- Rules (emulator), audit group rewritten (4 tests) + archive/restore test: a real edit with its entry accepted; owner-only read; no rewrite/delete; **forged entries refused** (no edit in the commit, invented fields, a mix of real and invented fields, wrong order number, non-existent parcel, another user's parcel, writing into someone else's log); **action must match** (plain edit cannot be logged as archive/restore/return/resolve_review/correct_payment); malformed entries refused even beside a real edit; archive/restore entries only with the matching change. **80 rules tests passed.**
- Mutation check: removing the "fields really changed" clause makes the forged-entry test fail.
- Real repository (Android emulator): every action that writes an audit entry — edit, notes, Pay Later date, return, review completion, correction (amount and date-only), archive, restore — still succeeds under the stricter rule: **34 passed**. `flutter analyze` clean; `flutter test` 943 passed.

## Security implications
Cross-user access unchanged (denied). A client can no longer add an entry that does not correspond to an actual, simultaneous change.

## Remaining risks (not claimed as secured)
1. A modified client can still **omit** the entry for an edit (nothing forces one entry per write), or write several entries for one edit. Tamper-evidence for omissions would need a server-side trigger (Cloud Function; Blaze plan; not added without approval).
2. Payments are not audited separately; the payment document is the record (append-only, DT-002).
3. Deploy rules with the app build: older builds that log the old field lists would be refused.
