# DT-012 — Firestore performance and cost (MEDIUM)

**Status: PARTIALLY FIXED** — repeated payment reads are removed with a bounded, safe cache; the parcel-list design is unchanged on purpose; scale beyond 600 parcels was not measured.

## Query review
| Query | Behaviour | Decision |
|---|---|---|
| `parcels` live stream (`watchAll`, `watchArchived`, `watchAll(includeArchived)`) | Whole list, kept in memory; search, filters, dashboard totals and customer figures are computed from it (plan D20/D21). After the first load, Firestore's local cache means a reopened app is billed only for changed documents | **Unchanged.** Pagination would break in-memory search/totals; not justified at the current size. Revisit with real data (D20) |
| `payments` sub-collection per parcel (`paymentsFor`, used by the payment-history report and the payment-date filter) | One query per parcel, every time a report is opened or a filter is applied; an empty sub-collection still costs a read | **Fixed:** bounded per-session cache (below) |
| `audit_logs`, `customers`, `products` | Written/read as needed, no unbounded scans in screens | Unchanged |
| Indexes | Only single-field `orderBy`; `firestore.indexes.json` is empty and sufficient | Unchanged |
| Subscriptions | Owned by `LiveListViewModel` / widgets and cancelled on dispose (reviewed; the unreadable-parcels notice owns and cancels its own) | Unchanged |

## The fix
`FirestoreParcelRepository.paymentsFor`: payments of a parcel are cached for the session, keyed by user and parcel. An entry is used only while the parcel's **payments signature** (`receivedPaisa | lastPaymentId`) equals the one the entry was read under. Since DT-002 every payment, correction and date-only correction moves `lastPaymentId`, so any change makes the entry stale and it is read again. The signature is taken from the parcel streams the repository already serves and *before* the read, so a payment landing meanwhile only makes the entry look stale (never wrongly fresh). Without a known signature nothing is cached. At most 5,000 parcels are cached (cleared when exceeded). `Parcel.lastPaymentId` / `paymentsSignature` added. A diagnostic counter `paymentQueries` shows reads.

## Measurements (Android emulator API 36 + Firebase emulators, one run, 8 Nov 2026)
600 parcels (200 with a payment), written in one go:
| Step | Result |
|---|---|
| First list of 600 parcels | 499 ms |
| Payments for all 600 — before (every call) / first call | **600 queries, 5,058 ms** |
| Payments for all 600 — second call, nothing changed | **0 queries, 0 ms** |
| After one new payment on one parcel | **1 query** (that parcel), the new payment is returned |
| After a correction of that payment | **1 more query**; payment, reversal and replacement returned |
Before the change, each report open or filter change cost the first-row figure again.

## Tests
- Emulator suite: 37 parcels tests pass (new "load and payment reads" test asserts the query counts above and correctness of the data after a payment and a correction). `flutter analyze` clean; `flutter test` 948 passed.

## Not done / limits
- 1,000 and 10,000 parcels were **not** run (600 only); emulator timings are not real-network timings; read *billing* was not measured, only query counts. Memory/leak profiling (DevTools) not done.
- No pagination, no collection-group payment query (it would need an owner uid on payments and a new index plus rules, a schema change).
- Identical live queries from several tabs (and `watchUnreadable`) are expected to share one server watch in the SDK; this was not measured.
- `flutter drive --no-pub` is now used by the emulator runner because `flutter drive` re-ran `pub get` and stalled when another Dart process held the lock.
