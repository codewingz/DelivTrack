# DT-015 — Weak password policy; email verification (LOW)

**Status: PARTIALLY FIXED** — the app now requires a stronger password when choosing one; the server-side policy and email verification are owner/console decisions and were not changed.

## Before
Sign-up accepted any password of 6 characters (`AppValidators.password`, default 6), the same rule used when logging in.

## Changes (public sign-up, login and password reset all stay open and working)
- `AppValidators.newPassword`: at least **8 characters with a letter and a number**; used only where a **new** password is chosen (`AppTextField.password(isNew: true)` on the Sign-up screen, with a helper line). Login keeps the old rule, so existing 6-character passwords still log in (tested); password reset only asks for an email.
- Server "weak-password" message now reads "Password is too weak. Use at least 8 characters with letters and numbers."
- Error messages were already generic where it matters: wrong password and unknown email both give "Incorrect email or password."; password reset looks the same for a known and an unknown email. A duplicate sign-up says the email is already registered (needed for the user to recover; hiding it needs Firebase's email-enumeration protection, a console setting — see below).

## Tests
- Unit/widget: validator rules (empty, short, digits only, letters only, valid, passphrase), login accepts a 6-character password, sign-up blocks a number-less password with a clear message, existing sign-up/login/forgot-password tests pass. `flutter analyze` clean; `flutter test` 951 passed.
- Real `FirebaseAuthRepository` on the Android emulator against the Auth emulator (`test_emulator/auth_repository_test.dart`): valid new registration (named, signed in), duplicate email refused with the clear message, server-side weak password reported plainly, wrong password and unknown email give the same message, correct login works, password reset for a known and an unknown email behaves the same, account switching gives a different user. Whole emulator suite: auth 6 tests, parcels 37, customers 7, products 10 — all passed (runner prints 8/38/7/10 including setup/teardown).
- Not tested: the Auth emulator accepted a malformed email for password reset, so that case is not claimed.

## Not changed (needs owner approval)
1. **Server-side password policy** (Firebase console → Authentication → Settings → Password policy): the app rule can be bypassed by calling the Identity Toolkit API directly with the public key; only the console policy enforces it. Recommended: minimum 8 + require letters/numbers, "enforce".
2. **Email verification:** not required; adding `email_verified` to the rules would lock out unverified public users (a product decision). Optional and not built.
3. **Email-enumeration protection** (console): recommended, not changed.
