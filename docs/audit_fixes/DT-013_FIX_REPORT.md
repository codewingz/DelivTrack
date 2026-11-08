# DT-013 — Android reminder reliability (MEDIUM)

**Status: PARTIALLY FIXED** — the existing local-notification design was reviewed and judged sufficient; limits are now visible to the owner and documented; nothing about real-phone delivery is verified.

## Review (nothing assumed)
| Item | Finding | Evidence |
|---|---|---|
| Scheduling | Pay Later parcels with a date of today/later that still owe money → one notification at 09:00 Pakistan time, inexact, id = order sequence (replace, never duplicate); reconciled on every parcel change while Home is open | `reminder_schedule.dart`, `reminder_scheduler.dart`; unit tests (planned instants, unchanged left alone, changed replaced, removed cancelled, overlapping syncs, errors kept) |
| Date change / cleared / paid in full / returned | Handled by the same reconcile (not planned → cancelled) | `reminder_schedule_test`, `local_notification_scheduler_test` |
| Permission | Explained and asked only when a reminder is added while using the app, never at launch; declining does not request; already-granted is silent; Settings/Reminders show Off + Turn On | `reminders_notifications_test`, `settings_screen_test` |
| Reboot / app update | Plugin boot receiver declared for `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, QUICKBOOT (not exported) | `AndroidManifest.xml` |
| Sign-out / account switching | `cancelAll` on sign-out; Home bell and screens are rebuilt per session; notification text names the order, customer and amount only (no address, `visibility: private`) | `reminders_notifications_test`, `session_switch_test`, `local_notification_scheduler_test` |
| Tap navigation | Running app and cold start open the parcel | `reminders_notifications_test` |
| Today after 09:00 (plan D17) | **Not built.** The in-app bell/list show it immediately; no phone notification | decision below |
| Only synced while the app is open | Confirmed: `_keepPhoneInStep` runs from the open Home screen | `dashboard_screen.dart` |

## Decision on D17 and background sync (no new infrastructure)
A "notify about a minute later" reminder for a date set after 09:00 needs a persistent marker of what was already shown (otherwise every re-sync would notify again) — that means new storage infrastructure. Background re-sync (WorkManager/FCM) is likewise new infrastructure. The brief forbids adding either without proof they are necessary; the in-app bell and Reminders list already cover the case, so neither was built. They remain optional owner decisions.

## Changes
- Settings → Reminders: new "How phone reminders work" text (set up whenever the app is opened; arrive about 9:00 AM; a date set for today after 9:00 shows in the bell/list, not as a phone notification). Widget test added.
- `docs/MANUAL_DEVICE_CHECKLIST.md`: five new steps (date set after 9:00; date changed on another phone; app update; force-stop; offline save).
- `docs/DelivTrack_Development_Plan.md` §G2: states the limits and why D17 is not built.

## Verification
- `flutter analyze` clean; `flutter test` 948 passed (reminder, scheduler, settings, session tests included).
- **NOT VERIFIED — PHYSICAL DEVICE REQUIRED:** delivery at about 09:00, app swiped away, restart, app update, battery saver/Doze, force-stop behaviour, lock-screen privacy on a real phone. Emulator-only evidence from an earlier session is not claimed as device reliability.

## Remaining risks
Reminders for a date changed on another phone arrive only after the app is opened on this phone; force-stop cancels alarms until the app is opened; aggressive manufacturer battery managers may delay or drop inexact alarms. Owner action: run the checklist on a real phone.
