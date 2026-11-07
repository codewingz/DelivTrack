# DelivTrack — backup and recovery (FR-14, spec 8.4)

Last checked: 7 Nov 2026 against the real project `delivtrack-codewingz` (Firestore database `(default)`, `asia-south1`).

## Where things stand

| Protection | Status | Notes |
|---|---|---|
| Data stored in Cloud Firestore, synced as the user works | **On** | Every save is a server write; nothing is kept only on the phone. |
| Per-user privacy (`users/{uid}/...`, rules) | **On** | Rules deployed and emulator-tested. |
| **Delete protection** on the database | **On** (enabled 7 Nov 2026) | The database cannot be deleted by mistake. To remove it deliberately: `gcloud firestore databases update --database='(default)' --no-delete-protection --project delivtrack-codewingz`. |
| Scheduled backups (daily / weekly) | **Off — needs the Blaze plan** | The project is on the free Spark plan (`billingEnabled: false`). |
| Point-in-time recovery (35 days) | **Off — needs the Blaze plan** | Only the default 1-hour version history is available. |
| No records are ever deleted by the app | **On** | Parcels, customers and products are archived, not deleted; payments are append-only (a correction adds a reversal); the rules refuse deletes. This is the main protection against losing data by mistake. |

**Decision for the owner (D23):** switch the project to the Blaze (pay-as-you-go) plan to turn on scheduled backups. At this data size the cost is expected to be very small, but billing needs a payment method, so it is not something the app can do for you. Until then the "no deletes" design and the cloud copy are the safety net, and a backup/restore test (AT-30) cannot be run.

## Turning backups on (after Blaze is enabled)

```bash
# Daily backups kept for 7 days, weekly backups kept for 14 weeks (the maximum)
gcloud firestore backups schedules create --database='(default)' --recurrence=daily  --retention=7d   --project delivtrack-codewingz
gcloud firestore backups schedules create --database='(default)' --recurrence=weekly --day-of-week=SUNDAY --retention=14w --project delivtrack-codewingz

# Optional: point-in-time recovery (35 days)
gcloud firestore databases update --database='(default)' --enable-pitr --project delivtrack-codewingz
```

Then update the Backup note in **Settings** (`lib/features/settings/views/settings_screen.dart`) to say backups are on.

## Restoring (acceptance test AT-30)

A restore never overwrites the live database: it creates a **new** database, which is then checked.

```bash
gcloud firestore backups list --project delivtrack-codewingz --location=asia-south1
gcloud firestore databases restore \
  --source-backup=projects/delivtrack-codewingz/locations/asia-south1/backups/<BACKUP_ID> \
  --destination-database=restore-check --project delivtrack-codewingz
```

Check the restored database in the Firebase console (parcels, payments, customers, counters, audit logs), then either copy what is needed back or point the app at the restored database. Delete the `restore-check` database afterwards (turn its delete protection off first if it was enabled).

## Manual export (also needs Blaze)

```bash
gcloud firestore export gs://<bucket>/delivtrack-$(date +%F) --project delivtrack-codewingz
```

## Things that are intentionally not available

* CSV / Excel / PDF export of reports is not approved (spec 14.1). The reports are on screen only.
