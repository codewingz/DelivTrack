# DT-018 — No handler for unknown routes (LOW)

**Status: FIXED AND VERIFIED**

## Before
`GoRouter` had no `errorBuilder`; an address matching no page showed go_router's default error page.

## Change
`lib/routes/app_router.dart`: `errorBuilder` shows the shared `EmptyState` ("Page not found", "Go to Home" → `/home`) inside a Scaffold. The login redirect is unchanged, so a signed-out user opening an unknown address goes to Log in first and never sees the app. Tabs, parcel details and notification-tap navigation are untouched.

## Tests (`test/auth_routing_test.dart`, +4)
Signed in: unknown page shows "Page not found" and Go to Home returns to the dashboard; signed out: unknown address leads to Log in; a parcel id that does not exist shows the existing not-found state and the Back button returns to the dashboard; after sign-out a stale deep link to a parcel lands on Log in. Existing tests for the login/logout redirects, tab shell, customer routes and notification taps still pass. `flutter analyze` clean; `flutter test` all passed.

## Not tested
The system Back gesture on a physical phone (predictive back) — the widget-test Back button was used.
