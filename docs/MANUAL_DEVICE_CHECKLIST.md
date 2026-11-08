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

11. **Date set after 9:00 AM.** Set a Pay Later date of today after 9:00 AM: the bell and the Reminders list show it at once; no phone notification is expected (documented limit, plan D17 not built). Settings explains this.
12. **Date changed on another phone / app not opened.** Change a Pay Later date on a second phone; the first phone only learns the new date when DelivTrack is opened there. Open it once and confirm the old notification is replaced.
13. **App update.** Install a newer build over the old one with a reminder scheduled: it must still arrive (the plugin re-schedules on `MY_PACKAGE_REPLACED`).
14. **Force-stop.** Settings → Apps → DelivTrack → Force stop. Android cancels alarms of a force-stopped app, so the reminder will NOT arrive until the app is opened again; record what your phone does.
15. **Offline save (DT-004).** Turn on airplane mode, try to save a new parcel: expect "No internet connection. Check your network and try again." and no parcel; turn it off, retry: exactly one parcel and the next order number (no gap). (Not covered by the emulator tests.)

## Added for the public launch (items 1-15 above cover reminders and offline saving; these cover the rest of the app)
16. **Release build smoke test on production.** After the rules are deployed, install the **signed release APK** (not a debug build) on a real phone and log in with a throwaway account. Create a customer, a product, a parcel, receive a part payment, correct that payment's amount and then its date, mark a second parcel returned, complete its payment review, archive and restore a parcel. Every step must succeed. Afterwards delete the throwaway account and its data (`firebase firestore:delete -r users/<uid>` and delete the user) so the live project stays empty.
17. **Sign up, log in, reset on a phone.** Sign up with a new email: a 7-character password is refused, an 8-character one with letters and numbers is accepted. Log out and in. "Forgot password": the email arrives (check spam) and its link works. A second account on the same phone sees nothing of the first and starts at ADT-000001.
18. **Network changes.** Save a parcel while switching Wi-Fi to mobile data, and on a slow connection: no duplicate parcel after a retry, no skipped order number.
19. **Largest system text and display size.** Home, Add Parcel, Parcel details, Payments, Reports and the payment sheets stay readable with no clipped button or text.
20. **TalkBack.** Walk Login → Add Parcel → Receive Payment → Reports: every control is announced in a sensible order, statuses are spoken as words, the bell announces the due count.
21. **Back gesture and button.** On sheets, on a form with unsaved changes (the discard dialog), on a tab root (leaves the app), and after a notification tap.
22. **Small screen and keyboard.** On a 360 dp-wide phone or smaller (or the smallest display size) the keyboard never hides the field being typed in.
23. **Notification permission by Android version.** Android 13+: asked once, explained first. Android 12 or older (if a device is available): no prompt, reminders still arrive.
24. **Many parcels on a mid-range phone.** With a test account holding several hundred parcels, the Parcels tab, search, Payments and Reports open without long pauses (create the data on a test project, not on production). Record the numbers.
25. **If App Check is turned on (owner decision).** A release build installed from Google Play works; a debug build needs a registered debug token; record what a sideloaded APK does.
26. **Quota watch.** For the first days after launch, check the Firebase console usage page daily (reads, writes, auth sign-ups).

Record the phone model and Android version for each run.
