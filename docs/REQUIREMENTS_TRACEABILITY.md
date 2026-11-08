# DelivTrack — requirements traceability (7 Nov 2026)

Every functional requirement (FR-01…FR-14) and acceptance test (AT-01…AT-44) of `DelivTrack_Project_Requirements.md` v1.2, with where it is built and where it is verified. "Rules" = `test/rules/firestore_rules_test.dart` (Firestore emulator, two users, mutation-checked). "Emulator" = the Android-emulator flow tests that existed in `integration_test/` until 8 Nov 2026 (deleted at the owner's request, still in Git history at commit `2a8f97d`). Unit/widget tests live in `test/`.

## Not fully done — read this first

| Item | Why | What to do |
|---|---|---|
| **AT-30 backup restore test** (FR-14 backups) | Scheduled backups and point-in-time recovery need the Firebase **Blaze** plan; the project is on Spark (`billingEnabled: false`), and enabling billing needs the owner's payment method. | Owner decision D23. Everything is documented in `docs/BACKUP_AND_RESTORE.md` (commands for schedule, restore and the restore test). Until then: delete protection is ON, the app never deletes records, and Settings says backups are not on. |
| Notification behaviour **after a phone restart / battery saver / force-stop** (AT-18 on real devices, spec 8.3) | Not testable on the emulator reliably; the boot receiver is installed as the plugin requires. | Run `docs/MANUAL_DEVICE_CHECKLIST.md` on a real Android 13+ phone. |
| FR-02 "audited correction flow" for a historical sending date | The spec says to build it only "if the owner ever needs" it. | Not built (not needed now). |
| Optional / not approved (spec 14.1) | Report export (CSV/Excel/PDF), bulk payment marking, tracking lookups, rate calculator, SMS/WhatsApp, analytics, roles, offline-first | Not built, by the spec's scope rule. |

Owner decision (plan D1, spec v1.3): **DelivTrack is public. Sign Up is kept** and every user's data is isolated under `users/{uid}/…` with its own order sequence, enforced by the rules (two-user rules tests and emulator account-switching test). The requirements document now says the same.

## Functional requirements

| FR | Built | Verified by |
|---|---|---|
| FR-01 order numbers | counter transaction, `ADT-000001`, immutable, reserved when archived | emulator `parcels_repository_test` (numbers 1,2,3; 2 and 5 overlapping saves; archive then add); Rules (counter) |
| FR-02 automatic sending date | server-derived Pakistan date, hidden on Add, shown in Details, kept on edit | Rules (date = server's Pakistan date, locked); `parcel_form_test` (no field); emulator edit tests |
| FR-03 products | per piece / per kg, archive, snapshots in each parcel | `products_domain_test`, `products_screen_test`; emulator `acceptance_checks_test` (AT-08) |
| FR-04 Add / edit parcel | full form, defaults VPP/VPL, Other name, draft/sent, Pay Later date | `parcel_form_test`, `parcel_form_flow_test`, `parcel_edit_flow_test`, repository + Rules |
| FR-05 returns | Mark Returned with date and reason, review flag, locked afterwards | Rules; `parcels_repository_test`; `parcel_actions_flow_test` |
| FR-06 collection methods | A/B/C/D all built (Advance starts Pending until recorded) | Rules; payment/reminder/parcel tests |
| FR-07 payments | Mark Payment Received (prefilled with the balance, no overpay), "received on" for late entries, append-only history, corrections by reversal | Rules (+ mutation checks); `payment_flow_test`, `parcel_actions_flow_test`; `payment_sheet_test` |
| FR-08 reminders | in-app list + bell; phone notifications 09:00 Pakistan time, stable id, replace/cancel, tap opens the parcel, permission explained | `reminder_*` tests, `local_notification_scheduler_test`, `reminders_notifications_test`; emulator `notifications_test` (real delivery), `reminders_flow_test` |
| FR-09 no uploads | none exist | by construction |
| FR-10 search and filters | substring search (order, reference, customer, phone, product) + 6 filters + chips + paging, over all parcels | `parcel_search_test`, `parcel_list_view_model_test`, `parcels_search_screen_test`; emulator `parcels_search_flow_test` |
| FR-11 dashboard | all required figures, recent parcels, Add Parcel, Search | `dashboard_stats_test`, `dashboard_screen_test`; emulator `reports_flow_test` |
| FR-12 reports | Outstanding + 6 more, on screen, totals, date ranges | `reports_test`, `report_screens_test`; emulator `reports_flow_test` (total equals Payments, AT-24) |
| FR-13 customers | full-screen form, mandatory fields, details page, list shows parcel count and outstanding | `customers_flow_test`, `customer_form_test`, `customers_screen_test`, `customer_details_test`; emulator `customers_flow_test` |
| FR-14 account and backup | Firebase Auth login that persists, per-user rules, safe log out; backups: see "Not fully done" | `auth_routing_test`, `login_test`, `sign_up_test`, `session_switch_test`; Rules; emulator `session_flow_test` |

## Acceptance tests

| AT | Verified by |
|---|---|
| 01, 02 numbers, rapid saves | emulator `parcels_repository_test` |
| 03 archive then add | emulator `parcels_repository_test` (archiving); Rules |
| 04, 39 no sending date / expected / notes on Add | `parcel_form_test` (first look) |
| 05 date in Details, kept on edit | `parcel_details_test`; emulator edit tests |
| 06, 33, 34 products, pieces vs kg | `parcel_form_test`, `app_text_field_test` |
| 07, 35 mixed lines, per-parcel prices, totals | `money_test`, `parcel_domain_test`; emulator repository tests |
| 08 catalog edit after shipment | emulator `acceptance_checks_test` |
| 09, 11 postal reference and charge saved | emulator `parcels_repository_test` |
| 10, 44 search by order / reference | `parcel_search_test`; emulator `parcels_search_flow_test` |
| 12, 13, 14, 41 payments, automatic time, no attachment | `payment_sheet_test`; emulator `payment_flow_test`; Rules (server time) |
| 15 Free / Gift | Rules; `payment_tabs_test`; repository tests |
| 16 advance fully paid | emulator `payments_screen_flow_test`, `payment_flow_test` |
| 17 Pay Later without a date | `reminder_rules_test`, `reminder_schedule_test` (no notification, never overdue) |
| 18 date reached: bell, list, notification | `reminders_flow_test`; emulator `notifications_test` (real notification); real phone: checklist |
| 19, 43 full payment cancels reminder | `reminder_schedule_test`, `reminders_notifications_test`; emulator `reminders_flow_test` |
| 20 permission denied | `reminders_notifications_test` (banner; list still works) |
| 21, 22 returned parcels | Rules; emulator `parcel_actions_flow_test` |
| 23 combined filters | `parcel_search_test`, `parcels_search_screen_test` |
| 24 outstanding report | `reports_test`; emulator `reports_flow_test` |
| 25, 26 sign in / unauthenticated blocked | `auth_routing_test`; Rules (signed-out denied); `parcels_repository_test` (signed-out) |
| 27 another device | emulator `acceptance_checks_test` |
| 28 repeated Save | `parcel_form_test`, `payment_sheet_test`; emulator concurrency tests |
| 29 partial payment / correction | Rules; emulator `parcels_repository_test`, `parcel_actions_flow_test` |
| 30 restore from backup | **blocked: Blaze plan** (see above) |
| 31, 32 Add Customer flow, validation | `customers_flow_test`, `customer_form_test`, `parcel_form_test` (customer picker) |
| 36, 37, 38 postal service defaults / Other | `parcel_form_test` |
| 40 Parcel Details | `parcel_details_test` |
| 42 clear the Pay Later date | emulator `parcels_repository_test`; `reminders_flow_test` |

## How to re-run what remains

* `flutter analyze` and `flutter test` (≈ 900 tests; the rules tests are skipped without emulators).
* Rules: `firebase emulators:exec --only auth,firestore --project delivtrack-codewingz "flutter test test/rules"`.
* The emulator flow tests and the screenshot script were deleted; restore them from commit `2a8f97d` (`git checkout 2a8f97d -- integration_test test_driver`) if they are needed again. Real-phone notification checks: `docs/MANUAL_DEVICE_CHECKLIST.md`.
