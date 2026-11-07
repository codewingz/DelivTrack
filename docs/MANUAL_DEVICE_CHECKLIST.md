# Manual checklist on a real Android phone (notifications, spec 8.3 and AT-18)

The emulator proves scheduling and delivery. These things depend on the phone maker's battery rules, so check them once on a real device (Android 13 or newer; repeat on 14/15/16 if available). Use a test account.

1. **Permission.** Fresh install, log in. Open Parcels → add a Pay Later parcel with a date a few minutes ahead (set the date to today only works before 9:00 AM; otherwise use tomorrow and a phone clock change, or just verify steps 2–6 with tomorrow's date). The app explains and asks for notification permission once. Allow.
2. **Delivery.** With a Pay Later date of tomorrow, the reminder appears tomorrow at about 9:00 AM (it may be a few minutes late: inexact timing is intentional). The text shows order number, customer name, amount left and the date, and no address.
3. **Tap.** Tapping the notification opens that parcel (also when the app was closed).
4. **App closed.** Swipe the app away from recents; the reminder must still arrive.
5. **Restart.** Restart the phone with a reminder scheduled; it must still arrive.
6. **Battery saver / Doze.** Turn battery saver on; the reminder should arrive (possibly later).
7. **Denied.** Deny the permission: the bell and Reminders screen must still list due and overdue parcels, and Settings shows "Off" with a Turn On button.
8. **Reinstall / new phone.** Uninstall, install, log in: the reminders are scheduled again automatically (open the app once).
9. **Log out.** Log out, then check no reminder of that account remains on the phone; log in as another account: it sees only its own.
10. **Changed or cleared date / full payment.** Change the date, clear it, or pay in full: the old notification disappears and no duplicate appears.

Record the phone model and Android version for each run.
