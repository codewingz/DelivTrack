# AGENTS.md — DelivTrack

Instructions for AI coding agents working in this repository. These rules are mandatory.

**Read this entire file before starting ANY task, every time** (code, questions, reviews, git, docs). Re-read it at the start of each new task; do not rely on memory of an earlier read.

## 0. Project context

- **App:** DelivTrack — Android-only Flutter app for tracking Pakistan Post parcels, customers and payments. Multiple users may sign up, but **each user sees only their own data** (see Data isolation below). Never call it "Animate DelivTrack".
- **Stack:** Flutter, feature-first MVVM, `go_router`, Firebase Auth, Cloud Firestore. Theme: Emerald & Ivory (see `lib/constants/app_colors.dart`).
- **Spec:** `DelivTrack_Project_Requirements.md` is the source of truth for scope. Do not build optional ideas from its Section 14 unless approved. `DelivTrack_Demo_Ready.html` is a UX prototype only.
- **Git:** work on the `dev` branch. Do not commit to `main` unless the user says so. **Standing permission from the owner:** after each small piece is built, tested and verified (analyze + tests + emulator + UI check), commit and push it to `dev` without asking.
- **Data isolation (mandatory):** all business data lives under `users/{uid}/...` and Firestore rules allow access only when `request.auth.uid == uid`. One user must never be able to read or write another user's data. Every data feature needs a rules test with two users.
- **Deploy to Firebase (standing permission):** Firestore rules and indexes are deployed to the real project (`delivtrack-codewingz`) with the Firebase CLI after they pass the emulator tests. Never deploy rules that were not emulator-tested. Look at what is currently deployed before overwriting.
- **Verification commands:**
  - `flutter analyze` and `flutter test` (unit/widget)
  - Rules (two users, real emulator tokens): `firebase emulators:exec --only auth,firestore --project delivtrack-codewingz "flutter test test/rules"`
  - The `integration_test/` and `test_driver/` folders (emulator flow tests and the screenshot script) were **deleted at the owner's request on 8 Nov 2026**; they are in Git history (commit `2a8f97d` and earlier) if they are ever needed again. Rules and logic are covered by the rules tests and `flutter test`; check real behaviour on the phone or emulator by hand.
  - Deploy rules: `firebase deploy --only firestore:rules --project delivtrack-codewingz`; then confirm the deployed ruleset equals `firestore.rules`.
- **Firestore concurrency (verified live on the real backend, 7 Nov 2026):** mobile transactions are optimistic. When rules depend on the current state of a document (e.g. the order-number counter) and two writes overlap, the loser gets `permission-denied` (not the retryable `aborted`). Such writes use a small bounded retry with a fresh read (see `FirestoreParcelRepository.create`) and a concurrency test. Throwaway data created in the real project for such checks must be deleted afterwards (users via the Auth admin API, documents with `firebase firestore:delete -r`).
- **Verification per phase:** CLI (`flutter analyze`, `flutter test`) and the rules tests; then a manual look on the emulator or a phone for anything visual.
- **Notifications:** Pay Later reminders use `flutter_local_notifications` + `timezone` (owner-approved). Android build needs `compileSdk` 37, desugaring and the plugin receivers (already set). Check real delivery by hand with `docs/MANUAL_DEVICE_CHECKLIST.md`.
- **Where things are documented:** plan and decisions `docs/DelivTrack_Development_Plan.md`; requirement-by-requirement status and tests `docs/REQUIREMENTS_TRACEABILITY.md`; backups `docs/BACKUP_AND_RESTORE.md`; real-phone checks `docs/MANUAL_DEVICE_CHECKLIST.md`. Packages added with owner approval: `flutter_local_notifications` + `timezone` (reminders), `url_launcher` (tap-to-call; the `tel` query is in the manifest).
- **Secrets:** never put API secrets in app files or Git history. The Android upload keystore lives outside the repo (`~/.delivtrack-signing/delivtrack-upload.jks`) and `android/key.properties` holds its passwords; both are git-ignored and must never be committed, printed or shared. Release builds use them automatically (`flutter build appbundle --release`); without `key.properties` the build falls back to the debug key.

---

## 1. Mandatory workflow

### 1.1 Research pre-flight gate

Before writing or modifying any code, configuration, schema, test, generated definition, dependency, or technical documentation — and before answering any factual/technical question — research is a blocking gate, not optional guidance:

- Perform the applicable research (repository inspection, current official documentation, and a targeted live web search) before making the change, every time, regardless of how familiar the API/behavior seems from training data or a prior session.
- The response that contains the change (or the answer) must visibly state, in a "Research" note near the change: the specific sources actually consulted (official doc URLs/names, live web search queries and what they returned, or the exact repository files/commands inspected) and the access date. A change with no stated sources is incomplete, not merely under-documented — treat it the same as skipping the reuse search or skipping tests.
- Live verification against a running server/service (not just its written documentation) is required whenever a real instance is reachable and the claim concerns that service's actual behavior. A spec describing intended behavior is not sufficient when the real thing can be checked directly. Record what was verified and how (e.g. the exact request/response observed).
- When multiple sources could conflict (a spec vs. a live server, one package's docs vs. another's), reconcile them explicitly rather than picking the first one found — state which source governs the final decision and why.
- If no relevant official source exists, the live service is unreachable, or evidence is inconclusive, state that explicitly rather than proceeding on assumption; mark the claim unverified.
- This gate applies even to changes that feel small or "obviously correct". Familiarity is not a substitute for verification; prior mistakes in this project came from skipping this step on things that seemed obvious.

### 1.2 Before implementation

- Translate the request into observable acceptance criteria, including applicable loading, data, empty, stale/partial, failure, cancellation, and recovery behavior.
- Define the smallest coherent scope and state what will not change.
- Inspect repository instructions, architecture docs, ADRs, API contracts, folder structure, locked Flutter/Dart/plugin versions, nearby code, callers, tests, generated boundaries, and current working-tree state.
- Trace the affected flow from view through ViewModel/state, domain, repository/data source, network/storage/platform boundary, feedback, tests, and docs.
- Perform the reuse search in Section 2 before proposing a new symbol or file.
- Build a proportional failure, lifecycle/ownership, concurrency, security/privacy, accessibility, compatibility, migration, observability, and test matrix.
- For every changed error boundary, network/offline behavior, security/privacy decision, plugin/platform API, or dependency behavior, check current primary documentation and the repository's locked version. Record source, access date/version, and the decision affected.
- Plan code, tests, documentation, migration/rollout, rollback/recovery, observability, and validation together.
- Explain the capability gap and tradeoffs before adding a production dependency. Obtain approval when project policy requires it.

### 1.3 Minimum necessary code

Write the smallest complete, readable, and production-safe implementation that satisfies the acceptance criteria and all applicable error-handling, security, privacy, accessibility, lifecycle, compatibility, testing, observability, and documentation requirements. "Minimum" never permits omitting required behavior.

- Do not add speculative abstractions, helpers, wrappers, factories, layers, parameters, callbacks, configuration, extension points, dependencies, files, or defensive branches for theoretically impossible states without evidence.
- Model genuine invariants through types where possible. Surface invariant violations through assertions or explicit programmer failures — never silently ignore them or convert them into misleading fallback behavior.
- Before implementing or fixing behavior controlled by Dart, Flutter, a package, platform API, protocol, or external service:
  - inspect the repository, existing implementations, tests, exact errors, and locked versions;
  - check the applicable current official documentation; and
  - perform a targeted live web search for current issues, regressions, limitations, simpler supported approaches, and edge cases. Search using the exact API, dependency version, platform version, and error text where applicable.
- Research priority: official documentation and examples → official release notes → maintainer repositories and issue trackers → applicable standards → reputable community sources (e.g. Stack Overflow). Community answers, blogs, AI-generated snippets, and search summaries are supporting evidence, not sources of truth; verify their date, version, comments, corrections, and applicability.
- Never copy external code blindly. Understand it, check provenance and license where material, adapt it to DelivTrack architecture, and verify it with analyzer and tests.
- For behavior entirely specific to DelivTrack with no external technical dependency, external research may be N/A, but report the repository evidence and the reason.
- Prefer an existing repository implementation or supported platform/library primitive when it completely matches the required behavior, architecture, lifecycle, security, accessibility, and performance needs.
- Do not add or reuse a dependency merely to reduce line count. Confirm necessity, maintenance, security, privacy, license, transitive/native impact, platform support, app size, and architectural fit.
- For bugs, identify and fix the verified root cause with the narrowest safe change and add a regression test when feasible. Do not hide symptoms through broad catches, fallback values, arbitrary delays, retries, mounted checks, or lint suppressions.
- For features, implement only currently accepted behavior. No speculative future requirements or unused flexibility.
- Prefer straightforward, idiomatic code. Minimum code means economical and clear — not compressed, clever, densely chained, or hard to maintain.
- Do not create a helper merely to shorten one clear expression. Extract only when it represents a cohesive responsibility, removes proven duplication, improves meaningful testability, or makes non-obvious behavior safer and clearer.
- Keep unrelated refactoring out of the change unless necessary for a correct, safe, and verifiable implementation.
- If a simpler implementation satisfies the acceptance criteria and quality requirements as completely as a longer one, use the simpler one.
- Before completion, inspect every added file, symbol, abstraction, parameter, branch, dependency, and comment. Remove anything that does not directly support required behavior, an applicable quality requirement, a verified reuse boundary, or its tests.
- A larger implementation is acceptable only when the problem genuinely requires it; the completion report must explain why a smaller one would be incomplete or unsafe.
- Judge minimality conceptually, not through arbitrary line, file, function-length, or reuse-percentage limits.

### 1.4 During implementation

- Keep the diff focused and backward-safe unless a coordinated migration is explicitly part of the task.
- Use strong types, immutable state, narrow APIs, and explicit transitions.
- Do not hide design problems behind globals, service locators, broad catches, unsafe casts, non-null assertions, lint suppressions, or god components.
- Update tests and applicable documentation in the same change.
- Stop and reassess when discovered repository facts contradict the plan.

### 1.5 Before completion

- Re-read the request and acceptance criteria.
- Inspect the complete diff and working tree.
- Repeat the reuse, failure, async, lifecycle, security/privacy, accessibility, test, and documentation audits.
- Run applicable validation (`flutter analyze`, `flutter test`) and record the exact commands and outcomes.

---

## 2. Reuse before creation

Reuse applies to widgets, screens, layouts, design tokens, functions, classes, extensions, validators, formatters, mappers, DTOs, models, failures, events, services, repositories, use cases, providers, routes, assets, localization keys, tests, and tooling.

### Decision order

1. **Reuse unchanged** when semantics, interaction, accessibility, lifecycle, ownership, security, and performance match.
2. **Compose** established pieces when the need combines existing responsibilities.
3. **Extend** a stable API when the new behavior belongs to the same responsibility and compatibility remains clear.
4. **Refactor/extract** when real duplication exists or a stable shared concept is now proven.
5. **Create new** only when responsibility, domain meaning, interaction, lifecycle, accessibility, performance, or security differs materially.

### Widget rules (project owner's standing preference)

- Always check `lib/common_widgets/` first. Currently: `AppTextField` (with `.email`, `.password`, `.confirmPassword`, `.name`, `.search`, `.integer`, `.reference`, `.amount`, `.weight`, `.phone`, `.multiline`), `AppFieldLabel`, `AppChoiceField`, `PrimaryButton`, `EmptyState` (also used for load errors), `ListSkeleton`, `SearchableListPage` (full searchable live-list page: search, loading, error/retry, empty, Add button), `AppSelectField`, `AppDateField`, `StatusChip`, `CountBadge` (count on an icon; fixed-size text, a documented exception), `AppFormSheet` / `showFormSheet` (frame for every small action sheet: title, fields, error line, submit button, repeated-tap guard), `showConfirmDialog`, `AppLogo`, `BrandLoadingIndicator`. Shared non-widget pieces: `AppFailure`, `ActionViewModel` (loading/error/double-tap guard for any submit), `LiveListViewModel` (live stream list: loading, error, retry, dispose), `firestoreFailure` / `withFirestoreFailures()`, `collapseSpaces`, `normalizePhone` / `phoneSearchDigits`, `integration_test/test_helpers.dart` (pumpUntil, tapVisible, typeInto). Tab pages get their own `ScaffoldMessenger` (see `_tabPage` in the router) and the tab frame has no Scaffold of its own.
- A widget with a different name but the same task is reused, not duplicated.
- A same-widget-with-extra-behavior need (e.g. text field vs amount field) stays **one** widget: add the behavior as options/named constructors, do not create a second widget.
- If nothing suitable exists, create it once in `lib/common_widgets/` and use it everywhere.
- Keep code short. Tell the owner before adding a new widget.

---

## 3. Responsive and sizing policy

These rules are mandatory for every screen, layout, design-system component, and feature widget.

- Use Flutter's supported primitives: granular `MediaQuery` accessors, `LayoutBuilder`, `TextScaler`, `SafeArea`, `Flexible`, `Expanded`, `Wrap`, grids/slivers, and explicit constraints. Do **not** add `flutter_screenutil`, `sizer`, `flutter_adaptive_scaffold`, a community fork, or another responsive-sizing package unless an accepted ADR explicitly replaces this policy.
- Choose the mechanism by what must be measured: `MediaQuery.widthOf`/`sizeOf` for the app window; `paddingOf`, `textScalerOf`, `viewInsetsOf` and other granular accessors for window environment/accessibility; `LayoutBuilder` for the actual parent constraints allocated to a widget or shell.
- Drive structural layout from available width, never device labels. `MediaQuery.orientationOf` describes app-window aspect orientation and `OrientationBuilder` describes parent-constraint orientation; neither is the primary layout switch or proof of physical device orientation.
- Width classes use half-open boundaries: **XS <360, SM 360–599, MD 600–1023, LG 1024–1439, XL ≥1440** logical pixels. Material widths such as 600/840/1200/1600 are reference test cases, not replacement tokens. A component may use a content-driven local threshold when its allocated constraints require it; document and test that exception.
- Inside a width class, use flexible composition and explicit min/max constraints rather than scaling every dimension or scattering raw percentages. Derive grid columns from local constraints/item width where appropriate. Use `Center` plus `ConstrainedBox` to limit readable content; 1280 is an applicable content maximum, not a universal cap for dashboards, maps, tables, or data grids.
- Apply `SafeArea` once at the correct ownership boundary. Use `EdgeInsetsDirectional`, `AlignmentDirectional`, and directional positioning. Layout direction is left-to-right. Inspect `MediaQuery.displayFeaturesOf` only when a concrete fold/hinge requirement exists.
- Establish foundations before visual components. Keep width classes/control dimensions in `lib/design_system/foundations/sizing/`, spacing in `spacing/`, radius in `radius/`, and typography in `typography/`. The width classifier and primitive numeric tokens should be pure Dart; Flutter theme integration may use Flutter types.
- Initially call the width classifier directly with `MediaQuery.widthOf(context)`. Do not add a state-management breakpoint provider or `BuildContext` extension until non-widget consumption or repeated usage justifies it.
- Baseline reusable sizes:
  - spacing: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64
  - icons: 16, 20, 24, 32
  - minimum interactive target 48×48
  - large/primary control height 56; standard control height 48
  - compact visual height 40 only with at least a 48×48 hit target
  - input minimum height 52; interactive row/tile minimum height 48
  - text-bearing controls must grow or reflow for content
- Never scale typography from screen width. Read `MediaQuery.textScalerOf`, support nonlinear scaling, and test at **1.0, 1.3, and 2.0**. Default to grow/wrap/reflow; `MediaQuery.withClampedTextScaling` requires an individually proven, documented, and tested component exception and must not cap body text globally.

---

## 4. Async safety, lifecycle, disposal, concurrency, and memory

### 4.1 Async and mounted

- Never store `BuildContext` in a provider, repository, ViewModel, service, singleton, static field, or long-lived closure.
- Avoid carrying context across async gaps when stable dependencies/callbacks can be captured synchronously.
- After each relevant async gap, check `context.mounted` before using that exact context, or `mounted` in `State` before state/context/navigation/UI access.
- A check before `await` does not protect code after it. Re-check after every later relevant gap.
- Do not add meaningless mounted checks when no async gap or post-gap UI access exists.
- Mounted checks do not cancel work or ensure domain consistency; combine them with cancellation/operation identity.
- Never pass an async callback to `setState`. Await first, verify lifetime, then update synchronously.
- Enable and obey `use_build_context_synchronously`; suppress only a proven false positive, narrowly, with justification.

### 4.2 Ownership and disposal

- Record creator, owner, replacement point, cancellation/disposal point, and late-callback protection for each resource/operation.
- Subscribe in the appropriate lifecycle method and replace old dependencies correctly in `didUpdateWidget` or the matching owner lifecycle.
- Dispose/cancel locally owned text/scroll/page/tab/animation controllers, tickers, focus nodes, timers, stream subscriptions/controllers, listeners, observers, overlays, event channels, debouncers, ports/isolates, clients, sockets, media/file handles, and temporary files as applicable.
- Remove listeners using the same callback identity used when registering.
- Cancel superseded network/file/platform work where supported and ignore stale completion using operation identity/version checks.
- Do not dispose injected, provider-owned, parent-owned, route-owned, shared, or externally owned resources.
- Call `super.dispose()` last unless the current API explicitly requires otherwise.
- Ensure late callbacks cannot mutate dead state or retain object graphs.

### 4.3 Concurrency and memory

- Define the duplicate-action policy: ignore, join, queue, merge, cancel, or parallelize. (DelivTrack rule: repeated Save taps must produce exactly one parcel/payment.)
- Prevent older results from overwriting newer state.
- Serialize shared mutations/token refresh and avoid check-then-act races.
- Validate state transitions and reject impossible combinations.
- Debounce only for a product reason; own and dispose the timer/controller.
- Do not mutate a collection while iterating it.
- Raw isolate errors need an error channel; close ports and kill owned isolates. Prefer supported self-terminating helpers for bounded CPU work.
- Bound caches, queues, pagination buffers, image dimensions, payloads, collections, logs, retries, and retained telemetry.
- Do not allocate expensive objects, subscribe, perform I/O, or trigger effects in `build()`.
- Avoid static/global/closure references retaining widgets, contexts, routes, large graphs, or obsolete state.
- Profile performance in profile/release-representative mode on representative hardware. Record measurements; never call work optimized without evidence.
- For leak-sensitive changes, repeatedly enter/leave the flow, force/observe GC, use DevTools memory diffs/retaining paths, and use compatible leak-tracking tests if the project adopts them.
- Meaningful drafts, forms, queued work, and critical operations must survive or recover intentionally from process death.
- Use Flutter state restoration (`RestorationMixin`, a stable `restorationId`, registered/disposed `RestorableProperty` values) for appropriate serializable UI state such as the selected step, tab, scroll position, or small restorable field state. State restoration is **not** a durable business-data store: important drafts, financial records (parcels, payments), and queued work must be persisted transactionally in the appropriate repository/database (Firestore) and reconciled after relaunch.
- Test state restoration and true process-death recovery separately. Verify both the restored values and the route/destination reached after relaunch, instead of assuming restored widget properties restore the whole business flow.
