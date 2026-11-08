# DelivTrack

**Document:** Project Requirements & Development Specification  
**Version:** 1.4  
**Status:** Owner-reviewed scope, updated Android implementation baseline  
**Owner:** CodeWingz  
**Use:** Public Android app: anyone can sign up; every account is private to its owner  
**Last updated:** 8 November 2026

> **v1.3 account model (owner decision, 8 Nov 2026):** DelivTrack is launched **publicly**. Anyone can sign up with their own Firebase Authentication account. Every account has its **own private data** under `users/{uid}/…` (parcels, customers, products, payments, reminders, audit, its own order-number counter starting at `ADT-000001`). Firestore rules allow access only when `request.auth.uid == uid`, so one user can never read or write another user's data. Statements elsewhere in this document that say "one private account", "no public sign-up" or "one approved UID" are superseded by this note. Password reset is Firebase's standard email link. Firebase free-plan quotas are shared by all users of the project (see the development plan, section "Account model and quotas").

> **v1.4 (owner decisions, 8 Nov 2026): Add Parcel and Handover are two steps, and Home is redesigned.** *Add Parcel* creates the order only (customer, parcel type, products and agreed prices, optional Pay Later date) and always saves it as a **Draft**. *Hand over to post office* is a separate action on the parcel's details: the owner records the postal service, the slip reference, the delivery charge and the optional packed weight, and the parcel becomes **Sent**. The handover can be corrected later with **Edit handover**. Home shows the money still to collect as one hero, then quick actions, a "Needs attention" list (overdue and due-today reminders, drafts awaiting handover, returned parcels needing payment review) and the figures grouped as Parcels and Money. Where older text below puts postal service, reference or delivery charge on the Add Parcel form, this note supersedes it.

> **Scope rule:** Section 1–13 describes the requirements confirmed by the owner and the minimum technical behavior required to make them work. Section 14 clearly identifies optional ideas and open decisions. Developers must **not** treat optional ideas as approved features.

---

## 1. Product overview

DelivTrack is a small internal parcel, customer, and payment tracking app. The company sends parcels through Pakistan Post, receives a postal reference (such as VPP / VPL / VPR as printed on its slip), and later needs to know whether the related money has been received. The app replaces handwritten tracking and searching through paper slips.

### 1.1 Main goals

1. Add each outgoing parcel quickly and assign a **unique, automatically generated order number**.
2. Select one or more previously saved products instead of typing their names every time.
3. Save actual parcel weight, actual delivery charges quoted on the post-office slip, and the postal reference.
4. Record the postal reference and actual delivery charge from the paper slip, without storing its photo.
5. Track parcels sent as **post-office collection**, **advance paid**, **Pay Later**, or **free / gift**.
6. Record **returned parcels** separately from their payment status.
7. See money received, money pending, and customer credit balances.
8. Allow optional estimated payment dates for Pay Later parcels; show due reminders inside the app and in the Android notification bar.
9. Search by internal order number, postal reference, customer, or product; filter by date and status.

### 1.2 Out of scope unless separately approved

- A public customer portal (the business's own customers never log in). Public sign-up for the business owners who use the app **is** in scope (v1.3).
- A complete courier dispatch platform or automatic Pakistan Post tracking API integration.
- A multi-employee permission system.
- Automatic SMS/WhatsApp reminders sent to customers.
- Automatic calculation of official Pakistan Post rates (the real slip charge is entered manually).
- Integration with bank accounts or automatic confirmation that Pakistan Post has remitted funds.
- Uploading or storing photos/scans of the original post-office booking receipt.

---

## 2. Terminology and core concepts

| Term | Meaning in this app |
|---|---|
| **Order number** | App-generated internal identifier, e.g. `ADT-000001`. Not the post-office number. |
| **Postal service type** | Label chosen from VPP, VPL, VPR, or Other. Do **not** assume VPR's official meaning without checking an actual slip. |
| **Postal reference** | Exact identification/tracking/reference text printed on the post-office receipt. |
| **Parcel** | One dispatched package/order, which can include multiple products. |
| **Collection method** | How the product amount is paid: post-office collection, advance paid, Pay Later, free / gift. |
| **Parcel status** | What happened to the parcel: sent or returned. |
| **Payment status** | Financial state: not required, pending, partially paid, or fully received; overdue is derived only when an optional estimated date is set and passes. |
| **Expected amount** | Calculated from the actual unit prices negotiated for this parcel: sum of quantity × price/piece or kg × price/kg. It is displayed in Parcel Details, not manually entered in the Add Parcel payment section. |
| **Received amount** | Amount actually recorded as received, confirmed by the user. |
| **Outstanding amount** | `max(expected amount − received amount, 0)`, adjusted by any documented return/refund decision. |
| **Reminder** | Date/time-based task to notify the owner about unpaid Pay Later parcels with a selected estimated date. |

**Important:** Parcel status and payment status are **separate**. A returned parcel may already be advance-paid; a delivered parcel may still be unpaid. Never collapse these into a single all-purpose status.

---

## 3. Confirmed functional requirements

### FR-01. Auto-generated order numbers

- The user never enters the internal order number manually.
- The first app order is `ADT-000001` because historic orders were not counted.
- Later orders follow the sequence: `ADT-000002`, `ADT-000003`, etc.
- Creation must be **atomic** (one safe database operation): two quick saves cannot produce the same number.
- The number is immutable (cannot be edited), never reused, and remains reserved even if the parcel is archived.
- If saving fails, do not display a successful order. Gaps in the sequence are preferable to duplicate numbers.
- Store a separate internal document ID in addition to the human-readable order number.

### FR-02. Automatic parcel sending date

- **No Sending Date control on Add Parcel.** App automatically records the current Pakistan date (`Asia/Karachi`) when the parcel is first created.
- Show the saved sending date in **Parcel Details**, parcel history, lists, filters, and reports.
- Save a separate immutable creation timestamp for audit.
- If the owner ever needs to correct a historical date, handle it in an explicit audited correction flow in Parcel Details, never as a daily Add Parcel field.
- An edited parcel keeps its original sending date; editing does not reset the date.

### FR-03. Product catalog — sold by piece or kg

- Products page: add, view, edit, and archive a product.
- **Only product name and selling unit are required during product setup** (plus active/archive status handled by the app).
- Selling unit is one of: **Per Piece (quantity)** or **Per Kg (weight)**.
- Product catalog does **not** require a fixed selling price. Prices are normally agreed with each customer by phone, so the app asks for a **negotiated unit price inside each parcel product row**.
- For a Per Piece product, show **Quantity (pieces)** and **Price per piece (Rs.)** while adding the parcel.
- For a Per Kg product, show **Weight (kg)** and **Price per kg (Rs.)** while adding the parcel.
- A parcel may contain multiple different products, including a mix of piece and kg items.
- Store the product name, unit type, quantity/weight, negotiated price and line total as an immutable historical snapshot for each saved parcel.
- New catalog edits must not rewrite historical units or agreed prices.
- Archived products are not selectable in new parcels but remain visible in prior parcels.

**Price formula:** `expectedProductPayment = Σ (line quantity or kg weight × negotiated unit price)`. Free/Gift parcels have zero expected payment regardless of entered product quantities. Currency is PKR.

### FR-04. Add and edit parcel — streamlined owner-approved form

The **Add Parcel** screen displays only the fields needed to record the order. The post-office booking is a separate step (*Handover*, below):

| Field | Behavior | Required? |
|---|---|---|
| App order number | Auto-generated on save, never typed | Automatic |
| Sending date | Captured automatically, **hidden from the Add form** | Automatic |
| Customer | Select saved customer; **Add New** opens a separate full screen | Yes |
| Parcel type | Post office collection / Advance paid / Pay Later / Gift or Free | Yes |
| Product rows | Select one or multiple saved products | Yes |
| Per-piece quantity | Positive whole number if product sold per piece | Conditional |
| Per-kg weight | Positive decimal kg if product sold per kg | Conditional |
| Agreed product unit price | Price per piece or price per kg; entered while making the parcel | Yes for non-free parcels |
| Pay Later estimated date | Optional date; if set, schedule an owner reminder | Optional, only Pay Later |

**Explicitly NOT shown on Add Parcel:** Sending Date, a standalone Payment Details panel, a manually typed Expected Product Payment field, and Notes (optional). **Expected amount and Notes are on the Parcel Details screen.** Expected amount is computed from the product line prices; Notes can be added/edited after saving from Parcel Details. Payment Received is recorded from Parcel Details or payment lists, never by uploading a file.

**Customer creation navigation:** Tapping **+ Add Customer** on Add Parcel opens a **new, full Android screen** (not a bottom sheet). That screen requires customer **name, phone number, and address**. Saving returns to the parcel with the customer automatically selected.

**Automatic postal service rules:** Post-office collection → `VPP`; Advance paid → `VPL`; Pay Later → `VPL`; Gift/Free → `VPL`. Treat these as default user-interface suggestions, **not guarantees of official Pakistan Post eligibility**; the user can select another type. `Other` reveals a mandatory free-text service name. The postal reference number is an independent, prominent input under the service selector.

**Handover to the post office (separate step):** every new parcel is saved as a **Draft**. On the parcel's details screen, **Hand over to post office** opens a form with: Postal service (VPP automatically for post-office collection, VPL for advance, Pay Later and Gift/Free; VPR or Other editable; Other needs a manual service name), **Postal reference number** (required), **Delivery charges (Rs.)** (required, exact amount from the slip) and optional **actual packed parcel weight (kg)**. Saving makes the parcel **Sent** and reserves the reference. **Edit handover** corrects these details later (the old reference is released, the change is audited). A returned or archived parcel cannot be handed over. Treat the service suggestions as defaults, not guarantees of official Pakistan Post eligibility.

**Validation:** Require an existing customer with name, phone and address; one or more valid product lines; positive whole pieces or positive kg weight; positive negotiated unit price for paid products; nonnegative delivery charges; manual service name for Other; and unique normalized `(postal service, reference)` among saved parcels. Never permit a negative payment or reused internal order number.

### FR-05. Parcel and return status

The app must support:

- **Draft / Awaiting handover** — the order is saved but not yet handed over to the post office.
- **Sent** — handed over to Pakistan Post through the Handover step; the reference and delivery charge are recorded.
- **Returned** — parcel has come back or is marked as returned.

When marking a parcel returned:

1. Save the returned date automatically by default; allow a correction.
2. Allow a short return reason/note.
4. Flag any outstanding amount or existing advance as **Requires Payment Review**. A return does not automatically mean all money was refunded, cancelled, or still owed.
5. Keep the parcel in history and include it in returned-parcel reports.

### FR-06. Collection methods (the business cases)

#### A. Post-office collection / paid parcel

- The amount is expected to be collected/remitted via the post-office process.
- Start as **Payment Pending** until the business confirms the money was received.
- On **Mark Payment Received**, record the amount and automatically save the payment received date/time.
- Do not mistake parcel dispatch or delivery for payment receipt.

#### B. Advance paid parcel

- Customer has paid before dispatch.
- Record amount paid and its actual payment date (if entered later, allow correction).
- When the advance covers the expected amount, status is **Received / Advance Paid**.
- If the customer only paid part of the expected amount, show the remaining balance; handling partial amounts is described as a support rule below.
- Advance paid is a **collection method**, not a parcel-delivery status.

#### C. Pay Later parcel

- The customer will pay the company later. The app must display this method as **Pay Later** (not **Credit / Pay Later**).
- The estimated payment date is **optional**. Leave it empty when the customer has not committed to a date.
- When a date is provided, store it and schedule an owner reminder for that date.
- On the chosen date, show the reminder in **DelivTrack’s in-app notification center** and in the **Android phone's notification bar**, if notification permission is granted.
- Unpaid Pay Later parcels without a date stay visible in outstanding balances but must not produce invented-due-date notifications or be marked overdue.
- At the selected date, unpaid amounts are highlighted as due/overdue; the user can reschedule, clear the date, or mark payment received.
- Automatically record received payment date/time and cancel future reminders when fully paid.
- The reminder is directed to the **company's Android device**, not automatically to the customer.

#### D. Free / gift parcel

- Represents a product sent as a complimentary gift with **no product payment expected**.
- Expected collection amount is 0; financial state is **Not Required / Free**.
- No unpaid balance, no estimated payment date, and no Pay Later reminders.
- Still record products, weight, real delivery charges, post-office reference, postal reference, date, and recipient/customer where available.
- Never count free parcels as unpaid invoices.

### FR-07. Payment tracking and receipt of money

- Show **Pending**, **Partially Paid** (where applicable), **Received**, and **Not Required** clearly.
- Provide a prominent **Mark Payment Received** action on pending/Pay Later/advance balance parcels.
- Auto-calculate outstanding balance from expected amount and recorded payments.
- If marking full payment with one tap, default the amount to the remaining outstanding balance; user reviews before confirming.
- Prevent recording more than the amount due without an explicit separate adjustment/refund process.
- If payment was received on an earlier day and is being entered late, user should be able to correct the actual payment date; preserve the system entry timestamp separately.
- Never silently overwrite or delete an existing payment transaction.
- On fully settled Pay Later payments, automatically cancel future reminders.

**Supporting rule — partial payments:** Needed for real-world advances and Pay Later balances, but **partial-payment UX was not explicitly approved** as a standalone feature. The data model must support multiple payment entries safely; display an advanced partial-payment flow only if approved in Section 14.

### FR-08. Pay Later reminders and notifications

- The **estimated Pay Later date is optional**. A blank date means no scheduled notification, not a validation error.
- Choosing a date creates a scheduled reminder for that date in Pakistan time (`Asia/Karachi`).
- With permission granted, Android should display a notification in the system **notification bar even if the app is closed**, subject to Android scheduling/battery restrictions.
- The same due reminder must be visible in the app's notification bell/list and Pay Later reminder screen.
- Notification content: internal order number, customer, remaining payment amount, and estimated date; keep sensitive details out of lock-screen previews if configured.
- Tapping a notification should open the relevant Parcel Details through `go_router` deep navigation.
- User can change/remove the estimated date; update/cancel the scheduled reminder immediately.
- When payment balance reaches zero, cancel the reminder and remove it from unpaid alerts; preserve its payment history.
- Rescheduling must not cause duplicate notifications; store a stable per-parcel notification ID/revision.
- Never send automatic WhatsApp/SMS messages to customers without separate approval.
- In the HTML browser prototype, in-app alerts work; notification-bar behavior can only be demonstrated with browser notification permission while the page is open. The Android Flutter app must implement real local scheduling.

### FR-09. No document uploads

- Record postal references, delivery charges, received amounts, and payment dates as text only.

### FR-10. Search, filters, and views

Search by:

- App order number (e.g. `ADT-000042`).
- Exact or partial post-office reference (VPP/VPL/VPR number).
- Customer name (or other saved customer lookup field).
- Product name.

Filters:

- Sending date range.
- Payment received date range.
- Product.
- Collection method: postal collection / advance / credit / free.
- Payment status: pending / partially paid / received / not required / overdue.
- Parcel status: draft / sent / returned.

UI behavior:

- Show results directly without manually scrolling through all records.
- Combine filters and search terms.
- Display order number, customer, postal number, sent date, amount, balance, parcel status, and payment status in the list.
- Default sorting: newest first; keep pagination for growing history.

### FR-11. Dashboard

Display at minimum:

- Total parcels.
- Sent parcels.
- Returned parcels.
- Free/gift parcels.
- Parcels with received payment.
- Pending-payment count.
- Total payment received (PKR).
- Total outstanding payments (PKR).
- Pay Later balance (PKR).
- Advance-paid amount (PKR).
- Reminders due today and overdue.
- Drafts awaiting handover.
- Recent parcels and quick access to Add Parcel and Search.

**Layout (v1.4):** greeting; one hero card with the outstanding amount to collect and how much was received; quick actions (Add Parcel, Search); a *Needs attention* list that shows only items that have something in them (overdue, due today, awaiting handover, need payment review) or a calm all-clear; the figures grouped as *Parcels* and *Money* in a two-column grid; recent parcels in one card with View all. Every figure opens the list or screen behind it.

**Metric rules:** A received parcel count is not a sum of payment transactions. Free parcels are excluded from outstanding money. Returned parcels with unresolved payment adjustments should be clearly marked and must not silently change totals. Avoid double-counting advance payments as both a new payment and an additional receivable.

### FR-12. Reports

Confirmed report:

- **Outstanding Payment Report:** list all unpaid or partly paid parcels, their customer, reference, sending date, collection method, estimated date (if Pay Later), amount due, received amount, and outstanding balance; include totals.

Also provide these practical filtered views using the same data:

- Payment received history.
- Returned parcels.
- Free/gift parcels.
- Pay Later balances and overdue reminders.
- Product-wise and date-wise parcel lists.

**Note:** Downloadable Excel/CSV/PDF report export is optional unless later approved. On-screen reports and filters are in scope.

### FR-13. Customers — full-screen mandatory data

- **Add Customer opens a new screen**, from both Customers and Add Parcel.
- **Required:** Customer Name, Phone Number, Full Address. All three must be nonblank; phone should be validated for a realistic number.
- **Save Customer** returns to Customers, or returns to Add Parcel with the new customer selected if opened from the parcel flow.
- Editing a customer uses the same separate screen, prefilled with the current customer details.
- Customers list and detail screens display name, phone, address, total parcels and outstanding balances.
- Customer may have multiple Pay Later parcels with separate optional estimated dates.
- Editing a customer's details never changes historic payment records; archived/history records retain needed customer snapshots.

### FR-14. Account access and cloud backup

- **Public sign-up; each user has one private account** with its own private data and its own order-number sequence. No staff-role management and no sharing of one account's data between accounts.
- Sign in through **Firebase Authentication**.
- Store parcel, product, customer, payment, reminder, and audit metadata in **Cloud Firestore**.
- Cloud-saved records must remain available after signing into the same account on another supported device, and a user must never see another account's records.
- Log out safely; sensitive records must not be accessible without authorization.
- Cloud data is the primary record store. Define recovery/export procedures; syncing to Firestore alone is **not** the same as an independent backup.

---

## 4. Main screens and navigation

**Target platform:** Android only. Flutter implementation uses `go_router`; a static HTML/CSS/JavaScript prototype is provided for UX testing and is not the production Android app.

| Screen | Main content/actions |
|---|---|
| **Login / Sign up** | Firebase Auth sign in, public account creation and password reset by email. |
| **Dashboard** | Parcel/payment totals, due Pay Later notifications, recent records. |
| **Add Parcel** | Order only: customer, parcel type, product rows, optional estimated date; saved as a Draft. No sending-date field, expected total box, postal details or notes field. |
| **Hand over to post office** | Sheet on a Draft's details: postal service, reference, delivery charge, optional weight; makes the parcel Sent. *Edit handover* on a Sent parcel. |
| **Add / Edit Customer** | **Full screen** with required name, phone and address; go back to the previous screen after save/cancel. |
| **All Parcels** | Search by order/ref/customer/product, filter, select parcel. |
| **Parcel Details** | Sending date, customer address, product line prices, calculated expected payment, Notes, received amount, postal reference, payment and return actions. |
| **Payments** | Pending, received, advance and Pay Later collection. |
| **Pay Later Reminders** | Optional dates, due/unset lists, edit date, receive payment. |
| **Products** | Add/edit/archive product with `per_piece` or `per_kg`. No catalog selling price. |
| **Customers** | Customer history, outstanding balance, separate Add Customer screen. |
| **Reports** | On-screen outstanding balances and history; CSV demo export is optional for production. |
| **Settings** | Notification permission, logout, authorized account, backup information. |

**Suggested Flutter route structure:** `/login`, `/home`, `/parcels`, `/parcels/new`, `/parcels/:id`, `/customers`, `/customers/new`, `/customers/:id/edit`, `/products`, `/payments`, `/reminders`, `/reports`, `/settings`. Use a `StatefulShellRoute` for persistent main tabs and push the customer form as a full screen, not a dialog.

## 5. Detailed user workflows

### WF-01: First-time setup

1. Create your account on the Sign Up screen (name, email, password of at least 8 characters with letters and numbers), or log in if you already have one.
2. Sign in on Android.
3. Add products with **name** and **Per Piece** or **Per Kg** unit; do not save catalog prices.
4. Add customers with required name, phone number and address, or create them during parcel entry.
5. Grant Android notification permission if Pay Later reminders should appear in the notification bar.

### WF-02: Create a paid post-office parcel

1. Open **Add Parcel**; the sending date is automatically recorded and **not visible** here.
2. Select a saved customer, or tap **+ New** and create one on the full-screen customer form.
3. Select **Post office collection**. Default postal service becomes **VPP**.
4. Select one or more products; for each choose **piece quantity + price/piece** or **kg weight + price/kg** according to product setup.
5. Save. The app creates `ADT-...` as a **Draft** and calculates expected product payment from line prices.
6. Open **Parcel Details** (Sending Date, Expected Product Payment, Notes) and, once you have the post-office slip, tap **Hand over to post office** (see WF-03).
7. There is no Payment Details panel in the Add form.

### WF-03: Hand over a Draft to the post office

1. Add the parcel (WF-02): it is saved as a Draft with its automatic order number; Home shows it under *Awaiting handover*.
2. When the slip is ready, open the Draft and tap **Hand over to post office**.
3. Check the postal service, enter the slip's reference number and delivery charge (and optionally the packed weight), and tap **Hand Over**: the parcel becomes Sent.
4. If something was typed wrongly, tap **Edit handover** on the Sent parcel and correct it.

### WF-04: Receive a payment

1. Find an order by internal number or postal reference and open **Parcel Details**.
2. View automatically calculated expected amount, received amount and remaining balance.
3. Tap **Payment Received**, enter actual amount received and confirm.
4. Record the **current received date/time automatically**; do not ask to upload proof, take photos, or type the date in normal operation.
5. Update outstanding balance and payment history; clear due Pay Later reminders after full settlement.

### WF-05: Gift / free parcel

1. Select **Gift / Free**; postal service defaults to **VPL**.
2. Add product lines, quantities/weights, customer, postal reference and delivery charges.
3. Expected product payment is zero; it is excluded from unpaid balances and reminders.

### WF-06: Advance paid parcel

1. Select **Advance Paid**; postal service defaults to **VPL**, but can be changed to match the slip.
2. Add product rows and negotiated prices, save the parcel.
3. In Parcel Details record the amount already received. Payment date is recorded automatically; a partial advance leaves a visible balance.

### WF-07: Pay Later with optional date

1. Select **Pay Later**; service defaults to VPL (editable).
2. Select customer, product units, quantities/weights and negotiated prices.
3. Optionally set an **estimated payment date**. Saving without it must succeed.
4. If a date was selected, schedule a reminder for the Android notification bar and the in-app bell; otherwise show as unpaid without a due notification.
5. Reschedule or clear date from Parcel Details or Reminders.
6. When payment arrives, tap Payment Received. Save received date automatically and cancel the reminder after full payment.

### WF-08: Returned parcel

1. Open existing parcel and choose **Return**.
2. Record returned date automatically and optionally enter the reason.
3. Preserve product details, payment transactions and postal reference; keep any refund/advance review separate from parcel return status.

### WF-09: Search, reports and money review

1. Search any order or Pakistan Post reference without scrolling.
2. Filter by sent date, product, payment type/status and parcel status.
3. View outstanding, Pay Later, returned and received payments; jump to an order to record money.

### WF-10: Customer creation from parcel

1. On Add Parcel, tap **+ New** by the customer selector.
2. Open the full-screen Add Customer view, not a popup.
3. Enter **Name, Phone and Address** (all mandatory).
4. Save; return to Add Parcel, preserving the unsaved parcel data and automatically selecting the new customer.

## 6. Business rules and calculations

### 6.1 Payment and delivery charge separation

The **delivery charge paid to Pakistan Post** must not be treated as **customer payment received**. Save at least:

- `productAmountExpectedPkr` — **calculated from the saved per-parcel product line prices**, never a manual Add Parcel total
- `deliveryChargePkr`
- `totalRecordedReceivedPkr`
- `outstandingPkr`

For every product line:

- Piece item: `lineTotal = integerPieceQuantity × negotiatedPricePerPiece`
- Kg item: `lineTotal = decimalWeightKg × negotiatedPricePerKg`
- Expected product payment: `sum(lineTotals)` or `0` for a Free/Gift parcel.

Round and store money safely in integer paisa. Delivery charges are separate from product receivables. If the company charges the customer for postage separately, that needs its own future decision; do not assume it is included in remittance.

### 6.2 Payment state calculation

| Condition | Financial display |
|---|---|
| Free/Gift; expected amount = 0 | Not Required |
| Expected > 0; received = 0 | Pending |
| Expected > received > 0 | Partially Paid / Balance Due |
| Received equals final amount due | Received |
| Pay Later with amount outstanding and a selected estimated date that has passed | Overdue (additional indicator) |
| Returned with advance/balance not resolved | Requires Payment Review (additional indicator) |

**Overdue** and **Requires Payment Review** are flags, not replacements for underlying financial/payment records.

### 6.3 Currency, time, and IDs

- Currency: Pakistani rupees (**PKR**).
- Store money as **integer paisa** or a consistently validated decimal type, not floating-point calculations that can lose precision.
- Display currency as `Rs. 2,500`.
- Store timestamps in UTC; display Pakistan local time (`Asia/Karachi`).
- Dates captured automatically must use authoritative server time when the record is committed, with corrected business dates stored separately.
- Use generated unique document IDs for relations; do not depend on customer names or postal references as database IDs.

### 6.4 Correcting mistakes

- Owner can edit parcel details and correct a payment entry.
- Financial corrections must be recorded as correction/reversal entries or audited changes, not silent deletion of historical payments.
- Order number never changes.
- Show saved/unsaved/error states clearly; disable Save while a submission is in progress to avoid accidental double save.

---

## 7. Data model — suggested Firestore collections

> This is an **implementation design**, not a new user-requested feature. Collection names may change, but the information and relationships below must be preserved.

> **All collections below live under `users/{uid}/…` (one private tree per account).**

### `users/{uid}/counters/orders`

- `lastSequence` (transactional counter; the order prefix `ADT` and the Pakistan time zone are app constants)

### `products/{productId}`

- `name` (required)
- `saleUnit`: `per_piece | per_kg` (required)
- `isActive`, `createdAt`, `updatedAt`
- **No fixed catalog selling price required**. Negotiated prices live in each parcel item.

### `customers/{customerId}`

- `displayName` **required**
- `phone` **required**
- `address` **required**
- `createdAt`, `updatedAt`

### `parcels/{parcelId}`

- `orderNumber`, `orderSequence`, `customerId`, `customerSnapshot` (name, phone, address)
- `items[]`: `{ productId, productNameSnapshot, saleUnitSnapshot, quantityPieces? , weightKg? , negotiatedUnitPricePaisa, lineTotalPaisa }`
- `actualPackedWeightGrams?` (optional separate gross parcel weight)
- `sendingDateLocal` **automatically stored on creation and hidden from the Add form**, `createdAt`, `updatedAt`
- `postalServiceType`: `VPP | VPL | VPR | Other`
- `otherPostalServiceName?` (required when Other)
- `postalReference`, `postalReferenceNormalized`
- `deliveryChargePaisa`
- `collectionMethod`: `postal_collection | advance | credit | free_gift` (`credit` is a legacy internal code; UI must show **Pay Later**)
- `productAmountExpectedPaisa` (calculated, not user-typed total)
- `estimatedPaymentDateLocal?` (optional for Pay Later)
- `parcelStatus`: `draft | sent | returned`
- `returnedAt`, `returnReason?`, `paymentReviewRequired`
- `notes?` (**entered/edited on Parcel Details, not Add Parcel**)

### `payments/{paymentId}`

- `parcelId`, `customerId`
- `amountReceivedPaisa`
- `receivedAt` (actual received date/time)
- `recordedAt` (system timestamp)
- `paymentType`: e.g. `advance | postal_remittance | customer_credit`
- `notes`
- `reversalOfPaymentId` / `correctionReason` (when needed)

### `reminders/{reminderId}`

- `parcelId`, `customerId`, `estimatedPaymentDateLocal` (set only if owner selected a date)
- `notificationId` (stable ID for Android scheduled local notification)
- `status`: `scheduled | shown | cancelled | failed`
- `scheduledForLocal`, `lastScheduledAt`, `revision`, `createdAt`, `updatedAt`
- A Pay Later parcel with no estimated date must have **no scheduled notification**.

### `audit_logs/{eventId}`

- `entityType`, `entityId`, `action`
- `changedFields`, `createdAt`, `actorUid`
- `reason` (for corrections/returns when supplied)

**Index requirements:** Build indexes for date/status/customer and Pay Later reminders. Firestore does not provide general full-text substring search by itself: implement normalized exact/prefix fields first, and choose a dedicated search solution only if necessary. For a small single-account dataset, client-side filtering over reasonably paginated, indexed result sets may be acceptable, but must not claim a search across all records if only one page was loaded.

---

## 8. Technical architecture and services

### 8.1 Confirmed providers

| Need | Selected service |
|---|---|
| Account login and sign-up | Firebase Authentication |
| Structured text/records | Firebase Cloud Firestore |

### 8.2 Needed implementation components

- **Android-only Flutter app** using feature-first **MVVM** (feature folders; ViewModel separates state/logic from widgets) and **`go_router`** navigation.
- **Firebase Authentication:** public sign-up enabled; email/password; password reset by email.
- **Cloud Firestore:** Products, customers, parcels, order sequences, payments, optional estimated dates and basic audit data. No Cloudflare R2 or image/file upload service.
- **Firestore rules:** Restrict each account's data to its own user (`request.auth.uid == uid`); enforce required customer fields and valid financial record structure.
- **Trusted order-number generator:** Use a Firestore transaction or a secure server endpoint to reserve `ADT-000001`, `ADT-000002`, etc. without duplicates.
- **Android scheduled notifications:** Prefer `flutter_local_notifications` for the single owner's **device notification bar**. Schedule locally when a Pay Later date is saved; update/cancel on edit/payment. Handle Android notification permission and any exact-alarm requirements. Firestore saves reminder date so it can be restored when the app is reinstalled or used on a new authorized phone.
- **In-app notifications:** Query Firestore Pay Later parcels with an estimated date on/before today and an outstanding balance; provide bell, list, and tap-through to Parcel Details. Keep this usable even if Android notification permission is denied.
- **Optional FCM:** Firebase Cloud Messaging is **not required for basic device-local scheduled reminders**. Add cloud push only if later needed for dependable cross-device scheduling or server-triggered alerts.
- **No attachments:** No original receipt photo, payment proof, camera, photo picker, PDF upload, or R2 storage.

### 8.3 Offline and reminder limitations

- The browser-based prototype uses localStorage and may show browser notifications only while its tab/page is open and allowed. It is **not** the production Android background notification system.
- Flutter Android local scheduled notifications can fire when the app is closed, but exact timing depends on Android notification permissions, alarm/battery rules and device settings; test on Android 13–16 and physical devices.
- If reminders are stored in Firestore and the app is reinstalled, download pending dates and reschedule device notifications upon next sign-in. Do not claim cloud push is operating without a configured backend.

### 8.4 Backup and recovery

- Firebase synchronization is the primary availability mechanism; **it is not sufficient as a point-in-time backup strategy**.
- Define periodic Firestore data backups and test a clear restore procedure.
- Verify recovery using a test restore before relying on it.
- Do not promise offline-first capability until explicitly designed and tested; normal operation may need internet.

---

## 9. Notification behavior in detail

### 9.1 Creating an optional date

- When **Pay Later** is selected, show one optional **Estimated Payment Date** field in Add Parcel.
- Blank date: save normally, keep outstanding balance, **do not schedule** notification and do not mark overdue.
- Selected date: schedule a local Android reminder for the device and expose the same alert through in-app bell/reminder list.
- Use `Asia/Karachi` as the business timezone. Choose a consistent default notification time (e.g. 9:00 AM Pakistan time) in the actual Flutter implementation; make the chosen time explicit in Settings. The user has not asked for separate time input.

### 9.2 Showing due reminders

- If `estimatedPaymentDate <= today` and `outstanding > 0`, show it in the in-app notifications list, even if permission for Android notifications is denied.
- Device notification bar should show order number, customer and unpaid amount when allowed.
- Notification tap navigates to `/parcels/:id` with `go_router`.
- Prevent repeated duplicate alarms for the same parcel/date. Give each parcel a stable notification ID and replace existing schedules on edits.
- Browser HTML demo limitations: it can only request desktop/mobile browser notifications; it cannot promise reliable Android notification-bar delivery after the browser page is closed.

### 9.3 Payment, editing and returns

- Full payment cancels pending notifications for that parcel; a partial payment keeps the reminder but shows its updated remaining balance.
- When date is changed, cancel old alarm and create new one; when date is cleared, cancel alarm.
- Returned parcel with unresolved payment receives a separate financial-review indication; never silently delete its payment history.
- Notification is to the **owner's device**, not the customer.

## 10. Screens — minimum interaction specifications

### 10.1 Add Parcel

- Show read-only `Auto-generated on save` for order number.
- **Do not show the Sending Date field**; populate it automatically and display it in Parcel Details.
- Customer dropdown and **+ New** action; New opens a **full screen** with Name/Phone/Address required.
- Parcel type: Post office collection / Advance paid / **Pay Later** / Gift/Free.
- Per product row: selector; either **quantity pieces** or **weight kg**, and negotiated **price per piece/kg**. Support multiple products.
- **No postal details on this form** (service, reference, delivery charge, packed weight): they are entered in the separate Handover step on Parcel Details.
- Only for Pay Later: optional estimated date; if present, schedule app + Android reminder.
- **No Add Parcel Payment Details section; no Expected Product Payment input; no Notes input.**
- Save always creates a Draft; the order number is reserved on save.
- After saving, go to Parcel Details where financial amount, notes and the **Hand over to post office** action are shown.

### 10.2 Parcel detail

- Show automatically saved sending date, order number, customer, phone, full address, product rows, piece/kg amounts, negotiated prices, line totals, weight, postal service/name/reference and delivery charges.
- Show **Payment Details here**: calculated Expected Product Payment, Received Amount, Outstanding Balance, Payment Status, optional estimated date.
- Provide **Notes (optional)** editing here, not on Add Parcel.
- Postal details section: shows "Awaiting handover" for a Draft with a prominent **Hand over to post office** button; a Sent parcel shows the recorded details and **Edit handover**.
- Show payment history with auto-captured dates; actions to receive payment, edit parcel, return, and change Pay Later estimated date.
- Returned and payment statuses must remain separate.

### 10.3 Pending and Pay Later lists

- Tabs/filters for Post Office Collection, Pay Later, Overdue and Returned Needing Review.
- Pay Later parcels with **no date** remain visible as unpaid but **not overdue**.
- Show outstanding totals and one-tap navigation; receiving payment needs confirmation.

### 10.4 Customer details

- Show required name, phone, full address and parcel/order history.
- Add/Edit customer opens a **new full screen**.
- Show outstanding, advance/received history and Pay Later reminder details.

## 11. Security and privacy

1. Public sign-up with one private data tree per account; no account can reach another's data.
2. Firestore security rules enforce the signed-in user's own `uid` and access checks, not just hidden UI buttons.
3. Never store API secrets in Flutter app files or Git history.
4. Validate customer name, phone and address; input length and numbers; reject invalid amounts.
5. Use Firestore transaction/server logic to prevent duplicate order IDs and double payments.
6. Save changes with clear success/errors; audit financial edits and corrections.
7. Avoid showing full customer address on phone lock-screen reminders.
8. No camera, photos, payment proof uploads, postal slip images, PDF storage, or Cloudflare R2.
9. Test Firestore backup/restore (owner-managed) and ensure each account can access only its own synced data (two-user rules tests).

## 12. Acceptance criteria — test cases

| ID | Scenario | Expected result |
|---|---|---|
| AT-01 | Create first parcel | Gets `ADT-000001`; no manual order number required. |
| AT-02 | Create two parcels in rapid succession | Distinct sequential numbers; no duplicates. |
| AT-03 | Delete/archive a parcel, then add another | Previous order number is not reused. |
| AT-04 | Open Add Parcel | Sending date field is **not displayed**; saving automatically stores the current Pakistan date. |
| AT-05 | View saved parcel | Automatically recorded sending date appears in Parcel Details; editing does not reset it. |
| AT-06 | Add same saved product to multiple parcels | Product is selected from dropdown without retyping. |
| AT-07 | Add piece and kg products to one parcel | Quantity/weight, agreed prices, and correct calculated total persist. |
| AT-08 | Edit product catalog after shipment | Old parcel's product snapshot remains unchanged. |
| AT-09 | Add postal number and slip charge | Exact number and actual charge are saved; no automatic charge replacement. |
| AT-10 | Search by order ID / postal reference | Correct parcel appears without manual scrolling. |
| AT-11 | Record postal booking details | Postal service, reference and actual charges saved without original slip photo. |
| AT-12 | Record payment without attachment | Payment saves immediately without file selection. |
| AT-13 | Mark postal payment received | Amount recorded; date/time auto-captured; outstanding updated. |
| AT-14 | Record payment details | Amount and automatic received date are saved. |
| AT-15 | Save a Free/Gift parcel | No receivable or reminder; delivery charges still recorded. |
| AT-16 | Save fully advance-paid parcel | Payment history shows advance; no unpaid balance. |
| AT-17 | Create Pay Later parcel with **blank** estimated date | Saves successfully, is unpaid, has no scheduled alarm, and is not overdue. |
| AT-18 | Set estimated Pay Later date and reach date | In-app bell/list shows reminder; Android local notification appears if allowed. |
| AT-19 | Full Pay Later payment received | Payment date saved; remaining reminders cancelled. |
| AT-20 | Android notification permission denied | Pay Later still appears as due/overdue in the app. |
| AT-21 | Mark unpaid parcel returned | Parcel status is Returned; financial balance flagged for review. |
| AT-22 | Mark advance-paid parcel returned | Payment remains recorded; refund/cancellation not assumed. |
| AT-23 | Filter by product and sending date | Only matching records returned; combined filter works. |
| AT-24 | View outstanding report | Shows correct pending/Pay Later balances, excluding Free/Gift. |
| AT-25 | Sign in with authorized account | Can access Firestore-backed company records. |
| AT-26 | Access without authentication | Blocked from records. |
| AT-27 | Sign in on another Android device | Synced parcel and payment records are available. |
| AT-28 | Save button clicked repeatedly | One parcel/payment transaction, not duplicates. |
| AT-29 | Partial payment / amount correction | Financial calculations remain correct and history is auditable. |
| AT-30 | Restore from backup test | Historical parcel and payment records are recoverable. |
| AT-31 | Tap Add Customer in Add Parcel | Opens separate full-screen form and preserves unsaved parcel; returning selects newly added customer. |
| AT-32 | Try saving customer with missing name/phone/address | Save is blocked with clear field-level errors. |
| AT-33 | Create Per Piece product | Add Parcel shows whole-number quantity and negotiated price per piece. |
| AT-34 | Create Per Kg product | Add Parcel shows decimal kg and negotiated price per kg. |
| AT-35 | Add products with different per-order prices | Previous parcel's prices remain unchanged; amount is calculated from saved line prices. |
| AT-36 | Change parcel type to post-office collection | Service defaults to VPP automatically. |
| AT-37 | Change parcel type to Gift/Free, Advance or Pay Later | Service defaults to VPL, remains manually editable. |
| AT-38 | Select Other postal service | Custom service-name input is displayed and required. |
| AT-39 | Create parcel | Add form has no sending date, standalone expected payment input, or Notes input. |
| AT-40 | Open Parcel Details | Shows expected total, payment details, Notes editor and sending date. |
| AT-41 | Mark payment received | Automatically stores receipt timestamp; does not request photo/proof. |
| AT-42 | Clear an estimated Pay Later date | Cancels scheduled reminder; overdue flag is removed. |
| AT-43 | Save Pay Later estimated date, then fully pay | Cancels device notification and clears in-app unpaid alert. |
| AT-44 | Search by postal number | Finds the exact parcel without scrolling. |

### Required testing types

- Functional tests for each workflow.
- Form validation and numeric boundary tests.
- Security rule tests and unauthorized-access attempts.
- Duplicate ID/concurrent transaction tests.
- Payment calculations and return/advance edge cases.
- Reminder scheduling across dates, offline Android restarts, changed estimated dates, cancelled alarms and app reinstalls.
- Responsive UX tests on the approved platform(s).

---

## 13. Suggested build order (not an approval of extra features)

1. **Flutter Android foundation:** feature-first MVVM, `go_router`, Emerald & Ivory Material theme and approved DelivTrack app icon.
2. **Firebase setup:** Firebase Auth with public sign-up, per-user Firestore rules, environments and backup plan (owner-managed).
3. **Products:** product name, unit = per piece/per kg, dropdown and archive; test history snapshots.
4. **Customers:** required name/phone/address full-screen form and return-to-parcel navigation.
5. **Parcels:** auto unique order ID, hidden automatic sending date, customer, multi-product lines, negotiated unit prices and totals.
6. **Post office booking:** VPP/VPL auto default, VPR/Other manual selection, postal reference, actual charges and draft/sent rules.
7. **Parcel Details:** calculated expected amount, notes editor, automatic received date, payment records and returns.
8. **Pay Later:** optional date and in-app reminders; Android local notification scheduling and cancellation.
9. **Lists/reports:** search, combined filters, outstanding totals, payment and return history.
10. **Final QA:** validation, financial accuracy, Android notification permission/restart behavior, security, backup/restore and 44 acceptance checks.

**Completion rule:** For every small feature, implement it, test positive/negative cases, validate security and user flow, and only then move on.

## 14. Optional suggestions and unresolved decisions — NOT approved scope

### 14.1 Previously proposed but not expressly approved

- Automated Pakistan Post tracking lookups and delivery status synchronization.
- Price/rate calculator from Pakistan Post weight slabs (owner confirmed actual charge must be manually entered from slip).
- Excel, CSV, or PDF report export.
- Automatic WhatsApp/SMS reminders to customers.
- Advanced analytics/charts, profitability, and delivery-fee margin reports.
- Bulk payment marking for multiple parcels.
- Staff roles or one account shared between several people (not approved); independent accounts for separate businesses are supported.
- Built-in offline-first local data synchronization.
- Advanced partial-payment UI (underlying support for balances is included; exact interface needs approval).
- Automatically recurring reminders beyond the selected estimated date (not approved; avoid notification spam).

### 14.2 Remaining decisions — not blockers for the current prototype

| Item | Current decision | Implementation rule |
|---|---|---|
| Client platform | **Android only** | Flutter + feature-first MVVM + `go_router`. |
| App name | **DelivTrack** | Never call it Animate DelivTrack. |
| Colors | **Emerald & Ivory** | Primary `#176B56`, dark `#0B4D3B`, background `#EFF7F4`, white `#FFFFFF`, gold `#DCA044`. |
| Products | Per piece / Per kg | No fixed catalog price; negotiated price supplied on each parcel line. |
| Customers | Name, phone, address mandatory | New full-screen form. |
| Pay Later estimated date | Optional | Only schedule notification if a date exists. |
| Postal VPR | User may encounter this term; official meaning not verified | Keep VPR option and manual Other; do not invent postal-system integration. |
| Android notification default time | User did not set a time | Start with a documented default such as 9:00 AM Asia/Karachi, subject to OS rules; make adjustable in Settings only if later requested. |
| Returned parcel financial outcome | Requires review | Preserve payments and balance; never auto-refund. |
| Backup frequency | Not specified | Design/test Firestore backup strategy before production. |

## 15. Final project scope checklist

- [x] Product name **DelivTrack** only; Android-only Flutter app.
- [x] Feature-first MVVM, `go_router`, approved Emerald & Ivory theme and icon.
- [x] One Firebase Auth account and Firestore text data, no Cloudflare R2.
- [x] Auto order IDs starting `ADT-000001`.
- [x] **Sending date automatic but not shown in Add Parcel**; shown in Parcel Details.
- [x] **Customer Add/Edit in a separate screen**, name + phone + address all mandatory.
- [x] Products saved with **Per Piece** or **Per Kg** selling unit.
- [x] Per-parcel negotiated **price per piece** or **price per kg**, no fixed product catalog price.
- [x] Multiple products per parcel and automatically calculated expected product amount.
- [x] **No Add Parcel Payment Details**, Expected Product Payment field, or Notes input; display/manage those on **Parcel Details**.
- [x] Parcel type options: Post Office Collection, Advance Paid, **Pay Later**, Gift/Free.
- [x] Postal service auto VPP for collection and VPL for others; editable VPR / Other manual service name.
- [x] Clear separate **Postal Reference Number** field.
- [x] Actual delivery charge entered from paper slip; optional packed gross weight.
- [x] **Pay Later date optional**; Android notification bar and in-app bell when date arrives and money is unpaid.
- [x] Date can be changed/cleared; reminders stop after fully received payment.
- [x] Payment Received with **automatic payment date**, no proof photo/attachment.
- [x] Returns with separate payment review and retained history.
- [x] Search, filters, dashboard, outstanding report, customer history and backups.
- [x] Original post office slips and payment proof files **never uploaded/stored**.

---

## 16. Prototype limitations and production acceptance

The accompanying HTML/CSS/JavaScript prototype uses browser localStorage and sample records for testing flows. It does **not** connect to Firebase Auth/Firestore, cannot produce a native APK, and cannot guarantee Android system-bar notifications after the browser closes. The production Flutter Android implementation must implement real database security, safe order sequence generation and local Android reminders, then pass the test cases in Section 12.
