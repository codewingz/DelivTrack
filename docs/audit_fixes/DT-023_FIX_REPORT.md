# DT-023 — Firebase emulators listened on all network interfaces (LOW)

**Status: FIXED AND VERIFIED**

## Before
`firebase.json` set `"host": "0.0.0.0"` for the Auth and Firestore emulators. While tests ran, an unauthenticated test database was reachable from the local network. `lsof` during a run: `java *:8080`, `java *:9150`, `node *:9099`.

## Change
`firebase.json` → emulators `auth` and `firestore` use `"host": "127.0.0.1"`. Only the emulators section changed; the production project settings (project id, rules, indexes, app registration) are untouched, and nothing was deployed. (The emulator hub and logging servers already bound to loopback.)

## Verification
- `lsof -nP -iTCP -sTCP:LISTEN` during a run now shows `127.0.0.1:8080`, `127.0.0.1:9150`, `127.0.0.1:9099` (plus `127.0.0.1:4400`, `127.0.0.1:4500`, `[::1]:4400`).
- Rules tests through the emulators: 80 passed. Android emulator repository suites (auth, parcels, customers, products) connect and pass: 8 / 38 / 7 / 10 — the Android emulator reaches the host's loopback through its `10.0.2.2` alias, for both the Firebase SDK (`localhost` mapping) and the raw HTTP admin writes.
- Production configuration is separate: the app only talks to an emulator in the test files that call `useAuthEmulator`/`useFirestoreEmulator`.

## Note
A physical phone on Wi-Fi can no longer reach these emulators directly; use `adb reverse tcp:8080 tcp:8080` and `tcp:9099` (USB) when testing on a real device.
