# DelivTrack — Detailed Development Plan

**Based on:** `DelivTrack_Project_Requirements.md` v1.2 (source of truth), `AGENTS.md` (engineering rules).
**HTML demo:** used only to cross-check labels/placeholders. It is a sample, not a requirement.
**Written:** 7 Nov 2026. **Status:** PLAN ONLY — nothing here is built until the owner approves it, feature by feature.
**Branch rule:** all work on `dev`.

---

## 0. How to read this plan

- Every feature lists: **screens → every input field (type, keyboard, required, validation, error text) → actions → states (loading / empty / error) → business rules → data written → tests.**
- "FR-xx" / "AT-xx" / "WF-xx" refer to the requirements document.
- ✅ done · 🟡 partial · ⬜ pending.
- **Decisions needed from the owner** are collected in Section 14. Items marked **[DECISION n]** in the text point there.
- Section 16 lists the research this plan relied on (sources + date).

### 0.1 What is already built (✅)

| Area | State |
|---|---|
| Splash, Login, Sign Up, Forgot Password | ✅ (Sign Up is **not** in the spec — see D1) |
| Auth redirect, saved session, logout, remote-revocation sign-out | ✅ |
| Dashboard | 🟡 placeholder (greeting + logout only) |
| Shared widgets | ✅ `AppTextField` (+ email, password, confirmPassword, name, amount, weight, phone, multiline), `PrimaryButton`, `AppLogo`, `BrandLoadingIndicator`, `AuthScaffold` |
| Tokens | ✅ `AppSpacing`, `AppRadius`, `AppColors` (typography/icon/size tokens ⬜) |
| Tests | ✅ 128 unit/widget, 16 emulator integration tests |

---

## 1. Architecture and conventions

### 1.1 Folder layout (feature-first MVVM)

```
lib/
  design_system/foundations/{spacing,radius,sizing,typography}/
  common_widgets/            # reusable widgets (reuse rule in AGENTS.md §2)
  core/{money,time,ids,errors,validators}/
  features/
    auth/ products/ customers/ parcels/ payments/ reminders/
    search/ dashboard/ reports/ settings/
      data/        # repository interface + Firestore implementation + DTO mappers
      domain/      # immutable models, enums, pure calculations
      viewmodel/   # ChangeNotifier per screen/flow
      views/       # screens + feature-only widgets
  routes/
```

- One repository interface per feature (fakeable in tests, as `AuthRepository` is today).
- ViewModels never hold `BuildContext`. Screens own and dispose controllers.
- All colors/spacing/radius from tokens; the guard test (`design_tokens_test.dart`) fails on raw spacing numbers.

### 1.2 Navigation (go_router)

Bottom-tab shell (`StatefulShellRoute`) with 5 tabs; the rest are pushed full screens.

| Tab | Route | Contains |
|---|---|---|
| Home | `/home` | Dashboard |
| Parcels | `/parcels` | All Parcels (search/filter) |
| Payments | `/payments` | Payments + Pay Later Reminders (two segments) |
| Customers | `/customers` | Customers |
| More | `/more` | Products, Reports, Settings |

Pushed routes: `/parcels/new`, `/parcels/:id`, `/parcels/:id/edit`, `/customers/new`, `/customers/:id`, `/customers/:id/edit`, `/products/new`, `/products/:id/edit`, `/reminders`, `/notifications`, `/reports/:type`, `/settings`.
Redirect rule (already built): signed-out → `/login`; signed-in never sees auth screens.
Android back: from a tab root exits app; from pushed screens pops. Unsaved-form back → confirm discard dialog.

### 1.3 New dependencies to approve (AGENTS.md §1.2)

| Package | Why | Notes |
|---|---|---|
| `intl` | `Rs. 2,500` and date formatting | first-party Dart package |
| `flutter_local_notifications` | Pay Later reminders in the notification bar (spec FR-08) | needs Android manifest work |
| `timezone` | schedule at 9:00 `Asia/Karachi` | |
| `fake_cloud_firestore` (dev, optional) | fast repository tests | otherwise use emulator only |

No responsive-sizing package (forbidden by policy). No state-management package (MVVM with `ChangeNotifier`).

---

## 2. Cross-cutting foundations (build first)

### 2.1 Money (`core/money`)
- Store **integer paisa**. `Money` value type: `fromRupeesText("2,500.50") → 250050`, `toDisplay() → "Rs. 2,500"` (decimals shown only when non-zero: `Rs. 2,500.50`).
- Parsing accepts digits, one `.`, max 2 decimals; strips commas/spaces; rejects negatives, `NaN`, > Rs. 99,999,999.
- Line total: piece = `qty × unitPaisa`; kg = `round(weightKg × unitPaisa)` (weight 3 decimals → round half up to whole paisa). Unit-tested with edge cases (0.001 kg, 0.333 kg × Rs. 100.10).
- Sum of lines = expected amount; **Free/Gift = 0 regardless of lines**.

### 2.2 Time (`core/time`)
- All business dates in `Asia/Karachi`. Timestamps stored UTC; `sendingDateLocal` stored as `yyyy-MM-dd` string + creation `serverTimestamp`.
- `PakistanClock` interface (real + fake for tests): `today()`, `now()`.
- "Overdue" = estimated date **before** today; "Due today" = date equals today.

### 2.3 IDs and order numbers (FR-01)
- Document IDs: Firestore auto IDs. Order number: `ADT-` + 6-digit zero-padded sequence (`ADT-000001`, grows past 6 digits naturally).
- Counter doc `app_settings/main.nextOrderSequence`. **One Firestore transaction** reads the counter, writes the parcel with its number, increments the counter. Gaps allowed, duplicates impossible.
- A single counter document is sufficient: Firestore documents a ~1 write/second sustained soft limit per document and this app has one user. **No sharded counters** (they cannot give gapless ordered numbers anyway).
- Save button disabled while saving; on failure nothing is shown as saved.

### 2.4 Shared validators (`AppValidators`, extend existing)
Existing: `required`, `email`, `password`, `confirmPassword`, `amount`, `weight`, `phone`. Add: `name` (2–60), `address` (5–200), `integerQuantity` (1–99,999), `kgWeight` (0.001–9,999.999, 3 decimals), `postalReference`, `serviceName` (2–40), `note` (≤ 500), `reason` (≤ 200), `dateNotInPast`, `dateRange`.

### 2.5 New shared widgets (`common_widgets`, built once and reused)
| Widget | Used by |
|---|---|
| `AppTextField` additions: `.integer`, `.reference`, `.search`; `.weight` gets a `decimals` option | parcels, products, search |
| `AppDateField` (read-only `AppTextField` + date picker, optional clear button) | Pay Later date, filters, return date |
| `AppDropdownField<T>` | product picker, service type, filters |
| `AppChoiceChips` / `SegmentedChoice` | parcel type, unit, status filters |
| `StatusChip` (payment/parcel/overdue/review, color + text, never color alone) | lists, details |
| `MoneyText` (formats `Rs.`; semantic label for screen readers) | everywhere money appears |
| `SectionCard` | details, reports |
| `EmptyState`, `ErrorState` (message + Retry), `ListSkeleton` | every list |
| `ConfirmDialog`, `BottomSheetScaffold` | payment, return, filters |
| `AppBarWithBell` (notification bell + badge) | tab roots |
| `ResponsiveBody` (SafeArea once + max-width 1280 + scroll) | every screen (replaces per-screen copies) |

Typography/icon/size tokens (AGENTS.md §3) are created with the first new screen: control heights 48/56/52, icon sizes 16/20/24/32, min target 48×48.

### 2.6 Standard screen states (every data screen)
| State | UI |
|---|---|
| Loading | skeleton rows (no spinner-only screen) |
| Empty | icon + one sentence + primary action ("Add your first product") |
| Error | message + **Retry**; never raw exception text |
| Offline | Firestore offline cache shows data; banner "Offline — changes will sync"; writes queue (Firestore default). Do not promise offline-first (spec §8.3) |
| Saving | button disabled + spinner; fields disabled |

### 2.7 Firestore security rules (non-negotiable; spec §11)
- **Per-user isolation (decided 7 Nov 2026):** all data is under `users/{uid}/...`; access only when `request.auth.uid == uid`. A second user can never read or write the first user's data. (Replaces the earlier single-owner-UID idea.)
- Field validation in rules: required fields, types, string lengths, non-negative integers.
- `orderNumber`, `orderSequence`, `sendingDateLocal`, `createdAt` immutable after create.
- `payments`: **create only** (no update/delete). Corrections are new reversal docs.
- Customers must have non-empty name/phone/address.
- Rules unit-tested with the emulator (allowed owner, denied stranger, denied unauthenticated, denied immutable-field edit, denied payment update).
- **Sign-up is only safe because of this rule** (a stranger could create an account but reads nothing) — see D1.

### 2.8 Audit log (`audit_logs`)
Written for: parcel edit (changed fields), return, payment correction, Pay Later date change, product archive. Fields: `entityType, entityId, action, changedFields, createdAt, actorUid, reason`.

---

## 3. Data model (Firestore)

| Collection | Key fields |
|---|---|
| `app_settings/main` | `companyName, orderPrefix="ADT", nextOrderSequence, timezone, reminderHour=9` |
| `products/{id}` | `name, nameLower, saleUnit(per_piece|per_kg), isActive, createdAt, updatedAt` |
| `customers/{id}` | `displayName, displayNameLower, phone, phoneNormalized, address, createdAt, updatedAt` |
| `parcels/{id}` | `orderNumber, orderSequence, customerId, customerSnapshot{name,phone,address}, items[{productId, productNameSnapshot, saleUnitSnapshot, quantityPieces?, weightKg?, negotiatedUnitPricePaisa, lineTotalPaisa}], itemProductNames[] (for search), actualPackedWeightGrams?, sendingDateLocal, postalServiceType, otherPostalServiceName?, postalReference, postalReferenceNormalized, deliveryChargePaisa, collectionMethod, productAmountExpectedPaisa, **receivedPaisa**, **outstandingPaisa**, **paymentStatus**, estimatedPaymentDateLocal?, parcelStatus, returnedAt?, returnReason?, paymentReviewRequired, notes?, searchOrderLower, searchCustomerLower, isArchived, createdAt, updatedAt` |
| `parcels/{id}/payments/{id}` (or top-level) | `amountReceivedPaisa (positive; negative only for reversal), receivedAt, recordedAt, paymentType, notes, reversalOfPaymentId?, correctionReason?` |
| `reminders/{parcelId}` | `parcelId, customerId, estimatedPaymentDateLocal, notificationId, status, scheduledForLocal, lastScheduledAt, revision` |
| `postal_refs/{service_normalizedRef}` | `parcelId` — uniqueness guard written in the same transaction as the parcel |
| `audit_logs/{id}` | see 2.8 |

`receivedPaisa / outstandingPaisa / paymentStatus` are **denormalized on the parcel** and updated **in the same transaction** that creates a payment — this is what prevents double/over payment and makes lists/dashboards cheap.

**Indexes to define:** `parcels` by (`parcelStatus`, `sendingDateLocal` desc), (`collectionMethod`, `sendingDateLocal`), (`paymentStatus`, `sendingDateLocal`), (`customerId`, `sendingDateLocal`), (`estimatedPaymentDateLocal`, `outstandingPaisa`), (`searchOrderLower`), (`postalReferenceNormalized`), (`searchCustomerLower`). Exact set confirmed when queries are written (Firestore tells you the missing index).

---

## 4. Feature: Products (FR-03) — ✅ DONE 7 Nov 2026 (phases 0–4 verified: CLI, emulator, screenshots)

> **Built as planned, with these decisions:** add/edit in a bottom sheet; search is client-side (all of a user's products are loaded, so it matches anywhere in the name); data under `users/{uid}/products` with name-guard docs for case-insensitive unique names (archived names stay reserved); products are archived, never deleted; add/edit need a connection (Firestore transactions). Money/time helpers were not built (not needed by Products) and move to the Parcels feature.

**Screens:** Products list (in More tab) · Add/Edit Product (bottom sheet **or** screen — product form has only 2 inputs; plan uses a bottom sheet) [DECISION 9].

### 4.1 Products list
- Search field (`AppTextField.search`, hint "Search products", filters by `nameLower` prefix; ≤ 60 chars).
- Segment: **Active | Archived**.
- Row: name, unit chip (`Per Piece` / `Per Kg`), overflow menu: Edit, Archive/Restore.
- Empty: "No products yet. Add your first product." + **Add Product** button.
- FAB: Add Product.

### 4.2 Add / Edit Product — **2 inputs**
| Field | Widget | Input | Req | Rules | Error text |
|---|---|---|---|---|---|
| Product name | `AppTextField` (capitalize words) | text | Yes | trimmed 2–60 chars; unique among **all** products (case-insensitive, `nameLower`) | "Product name is required" · "Use 2–60 characters" · "A product with this name already exists" |
| Selling unit | `SegmentedChoice` | Per Piece / Per Kg | Yes | one selected; default none (force choice) | "Choose how this product is sold" |

No price field (spec: negotiated per parcel). Active/archived is an action, not a field.

### 4.3 Rules
- Archive hides from new-parcel picker; old parcels unaffected (snapshots).
- Editing name/unit never changes saved parcels (AT-08).
- Changing unit shows a warning: "Existing parcels keep their old unit."
- Archive confirm dialog; restore needs no dialog.
- Name uniqueness checked by query + guarded by a lowercase-name doc id or transaction to avoid races.

### 4.4 Tests
Validation (empty, 1 char, 61 chars, duplicate, duplicate different case), archive/restore, archived excluded from picker, history snapshot unchanged (AT-06/08/33/34), responsive sizes × text scales, emulator CRUD, rules.

---

## 5. Feature: Customers (FR-13) — ✅ DONE 7 Nov 2026 (4 phases verified: CLI, emulator, screenshots at 4 sizes)

> **Update 7 Nov 2026 (customer details, tap-to-call):** a customer row now opens a **Customer details** page (`/customers/:id`): name, phone (tap to dial through `url_launcher`, approved; the manifest declares the `tel` query), address, totals (parcels, outstanding, Pay Later balance, advance received) and the parcel history (newest first; archived parcels not counted); Edit is in the app bar and opens the existing form. Parcel Details also has a copy button for the postal reference.

> **Built as planned, with these decisions:** Customers is a bottom tab; list rows show name, phone and address (parcel count and outstanding come with Parcels); tapping a row opens the Edit screen directly (a separate detail page with parcel history comes with Parcels); search matches names anywhere and phone digits in any written form (including +92); duplicate phone is a warning, not a block; leaving a changed form asks to discard; saving returns the customer id so Add Parcel can select the new customer; customers are never deleted. Tap-to-call is not built (needs `url_launcher`, awaiting approval).

**Screens:** Customers list · Customer Detail · Add/Edit Customer (**full screen, never a dialog**).

### 5.1 Add / Edit Customer — **3 inputs** (all required)
| Field | Widget | Keyboard | Rules | Error text |
|---|---|---|---|---|
| Customer name | `AppTextField.name` | text, capitalize words | 2–60 chars, not whitespace | "Customer name is required" · "Use 2–60 characters" |
| Phone number | `AppTextField.phone` | phone | digits after stripping spaces/`-`/`+`; accepts `03XXXXXXXXX` (11) or `+923XXXXXXXXX`/`923XXXXXXXXX` (12); landline 10–11 digits accepted; 10–15 digits overall; stored normalized (`phoneNormalized`) | "Phone number is required" · "Enter a valid phone number" |
| Full address | `AppTextField.multiline` | multiline, 2–4 lines | 5–200 chars | "Full address is required" · "Enter the full address (5–200 characters)" |

- Duplicate phone → **warning, not block**: "A customer with this number already exists: <name>. Save anyway?" (two customers can share a family phone) [DECISION 8].
- Save button disabled until valid (errors appear on touch/submit).
- **Opened from Add Parcel:** save returns to the parcel with that customer selected and **all unsaved parcel data intact** (WF-10, AT-31). Implementation: parcel form state lives in the Add-Parcel ViewModel above the route (kept alive), customer screen returns the new id via `context.pop(id)`.
- Edit never rewrites past parcels (customer snapshot) (spec FR-13).

### 5.2 Customers list
Search (name/phone prefix), sort by name, row: name, phone, **parcel count**, **outstanding (Rs.)**. Empty state + Add button. Tap → detail.

### 5.3 Customer Detail
Header (name, phone with **tap-to-call** [DECISION 10], address), totals cards (parcels, outstanding, advance received, Pay Later balance), parcel history list (newest first, paginated), Edit button.

### 5.4 Tests
AT-31/32, validation matrix (each field empty/short/long/invalid phone formats), duplicate-phone warning, return-to-parcel preserves form, edit doesn't alter old parcels, responsive.

---

## 6. Feature: Add / Edit Parcel (FR-01, FR-02, FR-04, FR-06) — ✅ DONE 7 Nov 2026 (phases A–E verified: CLI, rules, emulator, screenshots at 4 sizes)

> **Built as planned, with these decisions:** order numbers `ADT-000001` come from a per-user counter in the same transaction as the parcel (overlapping saves retry, verified on the real backend); postal references are unique per service through guard documents; money is integer paisa, weight integer grams; Pakistan date is fixed UTC+5 (no extra packages). Editing (Parcel Details → Edit) keeps the order number, swaps the reference guard, recalculates totals, can turn a draft into Sent, never turns Sent back into a draft, is blocked for returned parcels and for switching free↔paid after a payment, and writes an audit-log entry listing the changed fields. Payments, returns and the details actions come with the next feature (§7).

### 6.1 Add Parcel — fixed fields (**10 inputs + product rows**)
Order number is shown read-only: "Auto-generated on save". **No** sending date, expected amount, payment panel or notes on this screen (spec FR-04).

| # | Field | Widget | Input | Req | Rules | Error text |
|---|---|---|---|---|---|---|
| 1 | Customer | `AppDropdownField` / picker + **+ New** | search list | Yes | must exist | "Select a customer" |
| 2 | Parcel type | `SegmentedChoice` (4) | Post office collection · Advance paid · Pay Later · Gift / Free | Yes | one | "Select a parcel type" |
| 3 | Product rows | repeatable card (**3.1 below**) | — | ≥ 1 | max 20 rows; no duplicate product in two rows [DECISION 11] | "Add at least one product" |
| 4 | Postal service | `AppDropdownField` | VPP/VPL/VPR/Other | Yes | auto-default: collection→VPP; advance, Pay Later, free→VPL; editable; stops auto-changing once user edits it manually | "Select a postal service" |
| 5 | Other service name | `AppTextField` | text | Only if Other | 2–40 chars | "Enter the service name written on the slip" |
| 6 | Postal reference number | `AppTextField.reference` (auto-uppercase, no emoji) | alphanumeric (letters, digits, `-`, `/`) | **Sent:** yes · Draft: no | 5–30 chars; unique per (service, normalized ref) | "Postal reference is required to mark as Sent" · "Use 5–30 letters/numbers" · "This reference is already used on ADT-000123" |
| 7 | Delivery charges (Rs.) | `AppTextField.amount` | decimal (2 places) | **Sent:** yes · Draft: no | ≥ 0, ≤ 99,999,999 | "Enter the delivery charge from the slip" |
| 8 | Actual packed weight (kg) | `AppTextField.weight` | decimal (3 places) | No | > 0 if entered | "Enter a valid weight in kg" |
| 9 | Estimated payment date | `AppDateField` | date picker | No | **Pay Later only**; today or later (Karachi); clearable | "Date cannot be in the past" |
| 10 | (hidden) Sending date | auto | — | auto | set once, Karachi, never editable here | — |

### 6.1.1 Product row (each row)
| Field | Widget | Shown when | Rules | Error text |
|---|---|---|---|---|
| Product | `AppDropdownField` (active products only) | always | required | "Select a product" |
| Quantity (pieces) | `AppTextField.integer` | product is **Per Piece** | whole number 1–99,999 | "Enter a whole number of pieces" |
| Weight (kg) | `AppTextField.weight` (3 dp) | product is **Per Kg** | 0.001–9,999.999 | "Enter a valid weight in kg" |
| Price per piece / price per kg (Rs.) | `AppTextField.amount` | not Free/Gift | > 0 | "Enter the agreed price" |
| Line total | read-only `MoneyText` | live preview | computed | — |

Changing a product after typing clears the incompatible field (qty ↔ kg) with no crash. **Free/Gift:** price fields are hidden and disabled; expected total = 0 (spec).
A live **"Products total"** read-only line under the rows is shown for convenience, **not an input** (spec forbids a manual total field; showing the computed value is allowed — confirm in [DECISION 12]).

### 6.2 Save behavior (two buttons)
- **Save as Draft** — needs: customer, type, ≥1 valid product row. Postal ref and charge optional.
- **Save & Mark Sent** — additionally needs postal service(+name), reference, delivery charge.
- If only a Draft is possible the primary button reads "Save as Draft"; once reference + charge are filled it becomes "Save & Mark Sent" (single primary button that changes label) [DECISION 13].
- Single Firestore transaction: reserve order number → write parcel → write `postal_refs` guard (if reference given) → write reminder doc (if Pay Later with date). Then **navigate to Parcel Details**.
- Disabled while saving; double taps create one parcel (AT-28).

### 6.3 Edit Parcel (WF-03)
Same form, prefilled. **Immutable:** order number, sending date, creation time. Editing:
- Draft → Sent by adding reference + charge (AT-09/11).
- Changing items/prices recalculates expected amount. If new expected < already received → set `paymentReviewRequired` and show warning (never delete payments).
- Changing reference swaps the `postal_refs` guard in the same transaction.
- Changing type to/from Gift/Free when payments exist is **blocked** with explanation.
- Pay Later date change reschedules the reminder.
- Writes an audit log (changed fields).

### 6.4 Business rules summary
| Rule | Detail |
|---|---|
| Expected amount | Σ line totals; 0 for Free/Gift |
| Delivery charge | separate from receivable; never added to expected amount |
| Advance parcel | starts **Pending** until the advance is recorded in Parcel Details; Details shows a prominent "Record advance" action [DECISION 14] |
| Gift/Free | no payments allowed, no reminder, no outstanding |
| Archive parcel | order number stays reserved (AT-03) [DECISION 15] |

### 6.5 Tests
AT-01…05, 07, 09, 11, 28, 33…40; unit tests for money math; validation for every field (empty/short/long/invalid chars); duplicate postal ref; service defaults per type; Other reveals name field; free parcel hides price; quantity/kg switching; transaction failure shows error and **no** order number; concurrency test (two simultaneous saves → distinct numbers, on emulator); responsive sizes × text scales; keyboard/scroll behavior.

---

## 7. Feature: Parcel Details (FR-05, FR-06, FR-07) — ✅ DONE 7 Nov 2026 (phases F1–F4 verified: CLI, rules with mutation checks, emulator, screenshots at 4 sizes) — except tap-to-call and copy button

> **Built as planned, with these decisions:** payments live at `users/{uid}/parcels/{id}/payments`, append-only; the parcel's received/outstanding/status move in the same transaction and the rules check that the parcel moved by exactly the payment. **Backdating [D16] built:** "Entered late?" → "Received on" (not in the future, not before the sending date). **Corrections:** a negative twin (`rev_<id>`, one per payment) plus an optional replacement (`cor_<id>`) in one commit; reason 5–200 required; a reversal is final; no corrections on returned parcels; audit-logged. **Returns:** Sent → Returned only; the parcel is then locked except for notes; `paymentReviewRequired` is set when money was received or is owed (nothing refunded automatically). **Notes** 1–500 characters. **Pay Later date** today-or-later, clearable. Tap-to-call and the postal-reference copy button were added later (see §5). Reminders/notifications for the Pay Later date are §9.

**Read-only sections**
1. Header: order number, sending date (Karachi), parcel status chip, payment status chip, overdue / review flags.
2. Customer: name, phone (tap-to-call), full address.
3. Products: per row — name, qty or kg, agreed price, line total.
4. Postal: service (+ name if Other), reference (copy button), delivery charge, packed weight.
5. **Payment details:** Expected, Received, Outstanding, estimated date (Pay Later).
6. Notes (editable here).
7. Payment history list.
8. Return info (date, reason) if returned.

**Actions** (shown by state)
| Action | Shown when | Opens |
|---|---|---|
| Mark Payment Received | outstanding > 0 and not Free/Gift | Payment sheet (7.1) |
| Edit Parcel | always (limits in 6.3) | Edit screen |
| Mark Returned | status Sent | Return sheet (7.2) |
| Change / Clear Pay Later date | Pay Later, outstanding > 0 | Date sheet (7.3) |
| Edit Notes | always | Notes sheet/inline (7.4) |
| Correct a payment | on a history row | Correction sheet (7.5) |

### 7.1 Mark Payment Received (sheet) — 3 inputs
| Field | Widget | Rules | Error text |
|---|---|---|---|
| Amount received (Rs.) | `AppTextField.amount`, **pre-filled with outstanding** | > 0 and ≤ outstanding (checked again **inside the transaction**) | "Enter an amount" · "Cannot exceed outstanding Rs. X" |
| Payment type | `AppDropdownField` | Advance · Post office remittance · Customer payment | "Select a payment type" |
| Note (optional) | `AppTextField.multiline` | ≤ 200 | "Use at most 200 characters" |

Received date/time is **automatic** (system time); no date input, no proof upload (spec FR-09, AT-41). Confirm button disabled while saving. Writes payment + updates parcel received/outstanding/status + cancels reminder when outstanding = 0 — **one transaction** (AT-13/14/19/28/43). Partial payment keeps the reminder and shows the remaining balance.
**Backdated entry** (WF: payment received earlier): optional "Received on" `AppDateField` under an "Entered late?" toggle; `receivedAt` = chosen date, `recordedAt` = now (spec FR-07) [DECISION 16].

### 7.2 Mark Returned (sheet) — 2 inputs
| Field | Widget | Rules |
|---|---|---|
| Returned date | `AppDateField`, default today (auto), correctable | not future, not before sending date |
| Reason (optional) | `AppTextField.multiline` | ≤ 200 |

Effect: `parcelStatus=returned`, `returnedAt`; if received > 0 or outstanding > 0 → `paymentReviewRequired=true` ("Requires Payment Review"). **Nothing is auto-refunded** (AT-21/22). Reminder for returned parcels stays visible only in the Review list, not as Pay Later due.

### 7.3 Change Pay Later date (sheet) — 1 input
`AppDateField` (today or later, clear allowed). Save → update reminder doc + reschedule local notification (cancel old id, create new; no duplicates). Clear → cancel (AT-42).

### 7.4 Notes — 1 input
`AppTextField.multiline`, 0–500 chars, saved on confirm. (Notes live on Details only, never on Add.)

### 7.5 Correct a payment — 2 inputs
Reason (required, 5–200) + corrected amount. Creates a **reversal payment** (negative) plus a new payment; never edits or deletes the original. Audit-logged (AT-29).

### 7.6 Tests
Each action positive + negative; overpayment blocked (client **and** transaction); parcel with Free type cannot take payment; return flags; advance flows; late-entry dates; concurrent double tap; history ordering; screen-reader labels for chips; responsive.

---

## 8. Feature: Payments screen (FR-07, FR-12 view) — ✅ DONE 7 Nov 2026 (CLI, emulator two-user flow; screenshots batched with M6)

> **Built:** a Payments bottom tab (Home, Parcels, Payments, Customers, More). Header totals: Outstanding, Pay Later balance, Advance received (Gift / Free and returned parcels left out). Lists: Pending, Partially paid, Received, Advance, Pay Later, Overdue (a Pay Later parcel with a past date and money owed; no date is never overdue), Review (returned parcels that received or owe money). Gift / Free is never listed. Rows show expected, received, balance, status and the Pay Later date, with a Receive button that opens the same payment sheet. 20 rows per page with Show more (all parcels are already live in memory, so paging is on screen, not a separate query); pull-to-refresh re-subscribes.

Tabs (scrollable): **Pending · Partially paid · Received · Advance · Pay Later · Overdue · Review (returned)**.
Row: order number, customer, expected, received, **balance**, status chip, estimated date (Pay Later), tap → Details; trailing **Receive** quick action opens the same payment sheet.
Header totals: outstanding (excl. Free/Gift), Pay Later balance, advance amount.
Pay Later with **no date**: listed as unpaid, **never overdue**.
Pagination 20/page; pull-to-refresh; empty state per tab.
Tests: AT-17/24; list counts match totals; Free excluded; no-date Pay Later not overdue.

---

## 9. Feature: Pay Later reminders + notifications (FR-08) — ✅ DONE 7 Nov 2026 (G1–G2 verified: CLI, mocked-channel tests, real emulator notification, screenshots) — manual real-phone checklist (reboot, battery saver) still to do in M8

> **G1:** in-app Reminders screen (`/reminders`) and Home bell badge; the list is derived live from the parcels (Pay Later, not returned, outstanding > 0), so there is no separate reminder document. A date in the past is refused by the rules, so overdue arises only as time passes.
> **G2:** `flutter_local_notifications` 23 + `timezone` (approved 7 Nov 2026; build needs `compileSdk` 37, core-library desugaring and the plugin's two receivers in the manifest). The phone's scheduled notifications are reconciled with the parcels every time they change (`plannedReminders` → `ReminderScheduler.sync`): scheduled at **09:00 Pakistan time (04:00 UTC)** on the date, id = order sequence (replace, never duplicate), **inexact** timing (no exact-alarm permission), text = order number, customer, amount left (no address). A time that has already passed is not scheduled (the in-app list shows it) [D17 not built: it needs a persistent "already shown" marker, i.e. new storage infrastructure; Settings explains the limit]. Reminders are only (re)scheduled while the app is open; the plugin's boot receiver re-creates them after a restart or an app update. Payment in full, a new date, clearing the date, a return or a new phone/reinstall are all handled by the same reconcile. Sign-out clears every scheduled notification. Tapping a notification (running or launching the app) opens `/parcels/:id`. Permission: explained and asked when a reminder is added while using the app, once per session, never at launch; the Reminders screen shows a "notifications are off" banner with Turn On (falls back to system settings). Scheduling errors are kept in `ReminderScheduler.lastProblem` for Settings (M8).

### 9.1 Reminder Screen (segment inside Payments) and Notification Center (bell)
- Sections: **Due today · Overdue · Upcoming · No date set**.
- Row actions: Open details · Change date · Clear date · Mark received.
- Bell badge = due today + overdue count.
- Works with notification permission **denied** (in-app list always available, AT-20).

### 9.2 Scheduling rules
| Rule | Detail |
|---|---|
| When | date selected on a Pay Later parcel with outstanding > 0 |
| Time | **9:00 AM Asia/Karachi** on that date (documented in Settings; not user-editable unless approved) |
| ID | stable per parcel (`notificationId` stored in the reminder doc) → replace, never duplicate |
| Date today & 9:00 passed | show in-app immediately; schedule a one-time notification ~1 min ahead [DECISION 17] |
| Edit/clear date | cancel old, schedule new / cancel only |
| Full payment | cancel + mark reminder `cancelled`; partial keeps it and updates text |
| Return | reminder cancelled when marked returned with no outstanding; otherwise kept for review [DECISION 18] |
| Content | order number, customer name, remaining amount, date; **no address** (lock-screen privacy) |
| Tap | opens `/parcels/:id` through go_router |
| Reinstall / new phone | after sign-in, load reminders with date ≥ today & outstanding > 0 and **reschedule all** |
| Reboot | requires the plugin's boot receiver; **must be tested on real devices** |

### 9.3 Android specifics (from research)
- Android 13+: request `POST_NOTIFICATIONS` at runtime (prompt after the first Pay Later date is set, with an explanation screen, never at launch).
- **Exact alarms are not required** for a morning reminder. `USE_EXACT_ALARM` is restricted by Google Play to alarm/calendar apps; requesting `SCHEDULE_EXACT_ALARM` forces the user through a special-access setting and the plugin can throw if it is missing. Plan: schedule **inexact (allow-while-idle)** → notification may arrive a few minutes late but needs no special permission [DECISION 19].
- Wrap scheduling in try/catch, record failure in the reminder `status: failed`, and surface it in Settings.
- Test: Android 13/14/15/16, battery saver, force-stop, reboot, locked screen, permission denied/granted, timezone change, reinstall.

### 9.4 Tests
AT-17…20, 42, 43; unit tests with a fake scheduler (schedule/replace/cancel; no duplicates; partial vs full payment); manual device checklist.

---

## 10. Feature: All Parcels — search and filters (FR-10) — ✅ DONE 7 Nov 2026 (CLI, real-Firestore two-user flow; screenshots in the batched run)

> **Built, with one decision [D20 changed]:** all of a user's parcels are already loaded live, so search and filters run **in memory over every parcel** (no prefix-only Firestore queries, no "newest N results" caveat): substring search over order number (also just the digits), postal reference (spaces/case ignored), customer name, customer phone (any written form) and product names; 300 ms debounce with an owned timer; ≤ 60 characters. Filters (groups AND together, choices within a group are alternatives): sending date range, payment received date range, product (every product on any parcel, archived included), parcel type, payment status (incl. Overdue and Not required), parcel status. The payment-date range reads the payments of parcels that received money (10 at a time, reversed payments ignored, newest lookup wins). Active filters show as removable chips with a badge count; the screen says how many parcels/matches; Load more adds 20. The older plan text below describes the Firestore-query design that is no longer used.

### 10.1 Screen layout
Search field → filter button (badge with active filter count) → active-filter chips (removable) → list → "Load more".
Row: order number, customer, postal reference (+service), sending date, **expected**, **balance**, parcel status chip, payment status chip. Default sort: newest first. Pagination 20/page.

### 10.2 Search input — 1 field
`AppTextField.search`, hint "Order, VPP number, customer, product", ≤ 60 chars, debounced 300 ms (owned & disposed timer), clear (×) button.
How a query runs (Firestore has **no** substring/full-text search; only prefix range queries and `array-contains`):
| Typed text looks like | Query |
|---|---|
| starts with `ADT` or `ADT-`/digits | prefix on `searchOrderLower` |
| letters+digits resembling a slip reference | prefix on `postalReferenceNormalized` |
| otherwise | prefix on `searchCustomerLower`, **plus** `array-contains` on product-name tokens |
Results from the sub-queries are merged and de-duplicated. The UI must say "Showing matches from newest N results" whenever it is not searching all records (spec §7 warning) [DECISION 20].

### 10.3 Filter sheet — 7 inputs (combinable with search)
| Filter | Widget | Notes |
|---|---|---|
| Sending date from / to | 2× `AppDateField` | to ≥ from |
| Payment received date from / to | 2× `AppDateField` | queries the payments data |
| Product | `AppDropdownField` | includes archived |
| Collection method | multi `AppChoiceChips` | post office · advance · Pay Later · free/gift |
| Payment status | multi chips | pending · partial · received · not required · overdue |
| Parcel status | multi chips | draft · sent · returned |
| Reset / Apply | buttons | |
Firestore allows range filters on one field per query, so date-range + other filters need composite indexes and some combinations are filtered client-side over the fetched page (documented per combination).

### 10.4 Tests
AT-10/23/44, each filter alone and combined, no-results empty state, debounce, pagination, search by partial order number, by reference, by customer, by product; responsive.

---

## 11. Feature: Dashboard (FR-11) — ✅ DONE 7 Nov 2026 (CLI; screenshots in the batched run)

> **Built, [D21 decided]:** figures are computed **in memory from the parcels already loaded live** (no aggregation queries or summary document to keep in step), so a card's number always equals the list behind it. Cards: Total parcels, Sent, Returned, Gift / Free, Parcels with payment received, Parcels pending payment, Total received, Total outstanding, Pay Later balance, Advance amount, Reminders due today, Overdue, and Need payment review (only when there are any). Count cards open the Parcels list already filtered (`/parcels` with the filters as `extra`); money cards open Payments; reminder cards open Reminders. Quick actions: Add Parcel (then opens the new parcel) and Search. Recent parcels: the 5 newest. Rules: received counts are parcels, not transactions; Gift / Free never adds to outstanding; money received on a returned parcel stays in Total received while its unpaid balance is not outstanding, and the parcel is counted under Need payment review; Advance money counts once. The columns follow the width (1–4). Pull-to-refresh and a Retry on failure.

Greeting (✅). Metric cards (tap opens the matching filtered list):
Total parcels · Sent · Returned · Free/Gift · Payment received (count) · Pending-payment (count) · **Total received (Rs.)** · **Total outstanding (Rs.)** · **Pay Later balance** · **Advance amount** · Reminders due today · Overdue.
Also: **Recent parcels** (last 5), **Add Parcel** and **Search** quick actions, notification bell.
Rules (spec): received count is not a sum of transactions; Free excluded from outstanding; returned-with-unresolved shows a review marker and doesn't silently change totals; advance not double-counted.
Computation: **[DECISION 21]** either Firestore aggregation queries (count/sum) or a `stats/summary` doc maintained in the same transactions as parcels/payments. Aggregation support and limits must be confirmed against current Firestore docs before choosing (research was inconclusive).
States: skeleton cards, per-card error with retry, pull-to-refresh.
Tests: metric math from fixtures (every rule above), empty database, large numbers, responsive grid (columns from available width).

---

## 12. Feature: Reports (FR-12) — ✅ DONE 7 Nov 2026 (CLI + real-Firestore flow; screenshots in the batched run)

> **Built:** More → Reports lists seven on-screen reports (nothing is exported): Outstanding payments, Payment received history, Returned parcels, Gift / Free parcels, Pay Later balances, Product-wise parcels, Date-wise parcels. Each has From / To dates (applied to the sending date, received date, returned date or Pay Later date as appropriate), loading / empty / error states, totals pinned at the bottom, and a row opens its parcel. The Outstanding report's total equals the Payments screen's Outstanding (AT-24, tested); Free is excluded; the history lists reversals as negative amounts and its total is net. The payment history reads the payments of the user's non-free parcels, 10 at a time.

One **Reports** screen listing report types → `/reports/:type`. All are on-screen (CSV/PDF export is **not approved**, §14.1 of spec).
| Report | Columns | Totals |
|---|---|---|
| **Outstanding Payment Report** (confirmed) | customer, reference, sending date, collection method, estimated date, expected, received, outstanding | total outstanding |
| Payment received history | order, customer, amount, received date, type | total received |
| Returned parcels | order, customer, returned date, reason, review flag | count |
| Free / gift parcels | order, customer, products, delivery charge | count, total charges |
| Pay Later balances & overdue | customer, date, balance, overdue badge | total |
| Product-wise / date-wise parcels | product or date, count, quantity/kg | counts |
Each report: date-range filter (2 date fields), loading/empty/error states, tap row → Parcel Details, totals pinned at the bottom.
Tests: AT-24 and totals equal the Payments screen; Free excluded.

---

## 13. Feature: Settings, Auth leftovers, Backup — 🟡 DONE except scheduled backups (needs Blaze, owner decision D23)

> **Built 7 Nov 2026:** Settings (More → Settings): account email, reminder time (9:00 AM Pakistan time), phone-notification status with Turn On / system settings, last reminder-scheduling problem (if any), backup note, app version (checked against pubspec by a test), Log out with confirm. Logout also clears every scheduled notification on the phone [D22 done]. Sign Up kept [D1]. **Backup:** delete protection enabled on the database; scheduled backups and point-in-time recovery cannot be turned on without the Blaze plan; `docs/BACKUP_AND_RESTORE.md` has the exact commands and the restore test (AT-30), and Settings says plainly that scheduled backups are not on yet. See also `docs/REQUIREMENTS_TRACEABILITY.md` and `docs/MANUAL_DEVICE_CHECKLIST.md`.

### 13.1 Settings screen (no text inputs)
Account email (read-only) · Notification permission status + **Open system settings / Enable** button · Reminder time "9:00 AM (Pakistan time)" (info) · Last reminder scheduling error (if any) · Backup info text · App version · **Log out** (confirm) .

### 13.2 Auth leftovers
- **D1 Sign Up:** spec says no public sign-up. Options: remove screen, or keep with the Firestore owner-UID rule (data stays private either way).
- Logout confirm dialog; logout also cancels local notifications on the device [DECISION 22].
- Email verification and change-password are **not** in the spec (not planned).
- Custom reset email: sender name/subject/body customizable in the Firebase console (no code); custom link needs a hosted handler page (separate decision).

### 13.3 Backup & recovery (FR-14, §8.4)
Firestore scheduled backups need the **Blaze** plan (daily + weekly schedule, retention up to 14 weeks, restore creates a new database). **[DECISION 23]** accept Blaze billing (pay-as-you-go, usually pennies at this volume) or use a manual export routine. A restore **test** is part of acceptance (AT-30).

---

## 14. Decisions needed from the owner

| # | Question | My recommendation |
|---|---|---|
| D1 | Keep Sign Up (spec says no public sign-up)? | **DECIDED (owner, 7 Nov 2026): keep Sign Up. Multiple users allowed, each isolated: data lives under `users/{uid}/...`, rules enforce `request.auth.uid == uid`. This replaces the single-owner-UID model in §2.7/§3.** |
| D2 | Approve dependencies `intl`, `flutter_local_notifications`, `timezone` | Yes |
| D3 | Weight precision: 3 decimals for product weights | Yes (e.g. 0.250 kg) |
| D4 | Max amounts / row limits (Rs. 99,999,999; 20 product rows) | Yes |
| D5 | Bottom nav tabs: Home / Parcels / Payments / Customers / More | Yes |
| D6 | Payments + Pay Later Reminders as two segments of one tab | Yes |
| D7 | Currency display: hide `.00`, show decimals only when non-zero | Yes |
| D8 | Duplicate customer phone: warn, don't block | Warn |
| D9 | Product add/edit as bottom sheet (2 fields) | Bottom sheet |
| D10 | Tap-to-call on customer phone | Yes (needs `url_launcher`, new dependency) |
| D11 | Same product twice in one parcel | Block (merge instead) |
| D12 | Show a read-only live "Products total" on Add Parcel | Yes (it is computed, not typed) |
| D13 | One primary button whose label changes (Draft ↔ Sent) | Yes |
| D14 | Advance parcel starts Pending until the advance is recorded | Yes |
| D15 | Allow archiving/deleting a parcel? (spec mentions it in AT-03 but has no screen for it) | **DONE 7 Nov 2026: archive only, with confirm.** Allowed for a draft, a returned parcel, or one that owes nothing (paid in full, Gift / Free); an archived parcel is hidden from every list, total, reminder and report, is read-only (only Restore), and its order number stays reserved. More → Archived parcels lists them. Enforced in the rules (two-user tests, mutation-checked). |
| D16 | Allow entering a past "received on" date for late entries | Yes, behind a toggle |
| D17 | Reminder date = today after 9:00 | In-app immediately + notification ~1 min later |
| D18 | Reminders for returned parcels | Cancel when nothing owed; keep in Review otherwise |
| D19 | Inexact scheduling (no exact-alarm permission) | Yes |
| D20 | Search scope note when not all records are searched | Show "newest N" note; revisit if data grows |
| D21 | Dashboard totals: aggregation queries vs maintained summary doc | Decide after checking current Firestore aggregation docs |
| D22 | Cancel local notifications on logout | Yes |
| D23 | Switch Firebase to Blaze for scheduled backups | Yes (set a budget alert) |
| D24 | Partial-payment UI (spec says data supports it, UI "needs approval") | Yes — included in 7.1 |

---

## 15. Build order and milestones

| # | Milestone | Contents | Size |
|---|---|---|---|
| M0 | Foundations | money/time/ids, validators, new shared widgets, size/typography tokens, tab shell, Firestore rules + emulator rule tests | L |
| M1 | Products | §4 | M |
| M2 | Customers | §5 | M |
| M3 | Parcels (create/edit/list basic) + order numbers + postal-ref guard | §6, simple list | XL |
| M4 | Parcel Details + Payments + Returns | §7, §8 | L |
| M5 | Pay Later + notifications | §9 | XL |
| M6 | Search + filters | §10 | L |
| M7 | Dashboard + Reports | §11, §12 | M+M |
| M8 | Settings, backup, QA hardening | §13, 44 acceptance tests, Android 13–16 device pass | M |

Per AGENTS.md "completion rule": every feature → implement → positive + negative tests → security check → user-flow check → commit on `dev` → only then next.
After each milestone: `flutter analyze` clean, all tests green, emulator integration tests for the real flows, **visual check on emulator screenshots at 3 sizes** (this has not been done for the existing screens yet).

### 15.1 Test strategy (every milestone)
Unit (pure money/date/rules) · ViewModel with fake repositories · widget tests (validation, states, double-tap) · responsive matrix (5 sizes × text scale 1.0/1.3/2.0) · emulator integration tests for real Firebase behavior · Firestore rules tests · manual Android device checklist for notifications.
Mapping to spec acceptance tests: AT-01…05 (M3), 06…08 (M1/M3), 09…12 (M3/M4), 13…16 (M4), 17…20, 42, 43 (M5), 21, 22 (M4), 23, 44 (M6), 24 (M7), 25…27 (✅ auth + M0 rules), 28 (all saves), 29 (M4), 30 (M8), 31, 32 (M2), 33…35 (M1/M3), 36…38 (M3), 39…41 (M3/M4).

---

## 16. Research notes (accessed 7 Nov 2026)

| Topic | Source | Used for |
|---|---|---|
| Android notifications / exact alarms | flutter_local_notifications GitHub issues ([#1906](https://github.com/MaikuB/flutter_local_notifications/issues/1906), [#2033](https://github.com/MaikuB/flutter_local_notifications/issues/2033)), Zenn article on exact alarms | inexact scheduling, runtime permission, try/catch; reboot behavior **unverified → device test** |
| Firestore counter limits | Firebase talk thread on write rate limit; distributed counter articles | single counter doc is enough; sharding doesn't give gapless numbers (secondary sources) |
| Firestore search | Stack Overflow answers on prefix search | no substring search; prefix range + `array-contains`; one range field per query. Composite index and aggregation specifics **not confirmed → verify before M6/M7** |
| Firestore backups | [Firebase backups doc](https://firebase.google.com/docs/firestore/backups) | scheduled backups, Blaze plan, retention up to 14 weeks. Point-in-time recovery details came from a third-party tutorial → **unverified** |
| Auth session behavior | [Manage User Sessions](https://firebase.google.com/docs/auth/admin/manage-sessions) | already implemented |
| Spec | `DelivTrack_Project_Requirements.md` v1.2 (read in full; unchanged since first commit) | all functional rules |
