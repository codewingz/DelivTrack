# DT-020 — Pakistan time is a fixed UTC+5 constant (LOW)

**Status: NOT REPRODUCED as a defect — assumption confirmed, boundary tests added, no code change.**

## Review
- `lib/core/time/pakistan_time.dart`: business dates use a fixed `Duration(hours: 5)`; storage stays UTC (Firestore timestamps); display and "date" strings are Pakistan dates. The rules' `pakistanDate()` uses the same offset. `plannedReminders` uses 04:00 UTC = 09:00 PKT. `recordPayment`/`correctPayment` use noon Pakistan (07:00 UTC) for earlier days, which cannot cross a day boundary.
- Research (8 Nov 2026): web search "Pakistan Standard Time UTC+5 daylight saving … Asia/Karachi" — results (Wikipedia mirrors, time-zone sites) agree that Pakistan has not observed daylight saving since 2009 and Asia/Karachi is permanently UTC+5. No official IANA/government release note was found directly, so this rests on secondary sources; the app depends on it only through the one constant, documented in the file header.
- Decision: keep the fixed offset (no time-zone package for date logic, as the brief prefers). If the rule changes, the constant, `pakistanDate()` in `firestore.rules` and `reminderHourUtc` change together.

## Tests added (`test/pakistan_time_test.dart`, 8)
11:59:59 PM vs midnight vs 12:01 AM in Pakistan; the UTC-day/Pakistan-day gap; month/year/leap-day boundaries; UTC vs local input; noon-Pakistan payments stay on their day; display format; reminder instant is 9:00 AM Pakistan on the due date; reminder planning across the 11:59 PM / 12:01 AM / 9:00 AM boundaries. Existing tests cover the sending date (server date in rules), received-on dates and corrected historical dates. `flutter analyze` clean; `flutter test` passes.

## Not covered
The rules' server-side `pakistanDate(request.time)` cannot be exercised at a chosen clock time in the emulator; it is covered by comparing with today's date in the rules tests.
