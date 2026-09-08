# Lactic iOS — V1 Implementation Plan

Status: approved; in progress. See **Current state** for what is built today.

Last updated: 2026-09-08. Steps 0-4 of the order of work are complete.

This is the working plan for `lactic-ios`, the third Lactic repository. It is a
living document — update it as decisions change rather than letting it drift.
Read the root `AGENTS.md` first; where the two disagree, `AGENTS.md` wins and
this file should be corrected.

## Context

`/Users/chico/dev/lactic-ios` was empty at the start of this work; a building
skeleton now exists (see **Current state**). The rest of the Lactic ecosystem is
built and deployed: a Rails 8.1 API-only backend (`lactic-api`, Railway) and a
Next.js 16 portal (`lactic-web`, Vercel) implementing **both** role experiences —
`/client/**` for gym members and `/coach/**` ("Lactic Studio") for coaches.

The shared `AGENTS.md` (byte-identical in both repos, `CLAUDE.md` a relative
symlink to it) already names `lactic-ios` as the third repository and fixes its
shape in **ADR #2 — "iOS monorepo with two targets"** and §6.1 (`LacticKit` /
`LacticUI` / `LacticCore`). This executes a decision already recorded, against a
live API whose contract is fully readable from the Rails blueprints.

**Outcome:** a buildable, testable, CI-checked iOS monorepo whose **Lactic**
(client/iPhone) app is feature-complete against `/api/v1/client/**`, signing in
through `dev_login` against a local API, with the **Lactic Studio** (coach/iPad)
target scaffolded. Native Apple/Google sign-in and the `lactic-api` changes it
requires are deferred to a later pass (decision #7) — they are a ship gate for
the App Store, not a gate on building the app.

### Decisions taken with the user

| # | Decision |
| --- | --- |
| 1 | One repo, one Xcode project, **two app targets** (Lactic → iPhone, Lactic Studio → iPad-first); ~90% of code in three local SPM packages |
| 2 | Scope now: **full client app + Studio scaffold** (auth + client list) |
| 3 | Set logging uses a **persisted session buffer + retry outbox** — not full offline sync, not online-only |
| 4 | `lactic-api` changes ship alongside the iOS work as their own PRs in that repo — superseded in part by #7, which defers the auth ones |
| 5 | Deployment target **iOS 18.0** (overrides `AGENTS.md` §6.1's "iOS 26+", which must be corrected in all three repos) |
| 6 | ~~Fix the datetime format in `lactic-api` first~~ — **DONE**, [PR #46](https://github.com/enrico-querci/lactic-api/pull/46), deployed `b21bee6`, verified live |
| 7 | **Google Sign-In now; Sign in with Apple at the App Store gate.** `dev_login` stays as a DEBUG-only convenience. SIWA is a release blocker, not a development one — see below |
| 8 | **REST, not GraphQL** — considered and declined for v1; revisit at Studio's program builder |

---

## Findings that shape the implementation

### Wire-format traps — these break a naive `Codable`

| # | Trap | Evidence |
| --- | --- | --- |
| 1 | ~~Two datetime formats in one API~~ — **RESOLVED upstream, 2026-09-08.** `config/initializers/blueprinter.rb` now sets `datetime_format`, so every endpoint emits `"2026-09-08T10:07:51.048Z"` and `Date` columns stay `"YYYY-MM-DD"`. The iOS decoder needs one plain ISO-8601-with-fractional-seconds strategy, not a lenient multi-format one. | Deployed `b21bee6`; pinned by `test/controllers/api/v1/datetime_serialization_test.rb`, which asserts both rendering paths agree |
| 2 | **Decimals are JSON strings.** `set_logs.weight_kg` and `workout_exercises.weight` read back as `"70.0"`, but are **written** as numbers. | `test/controllers/api/v1/client/set_logs_controller_test.rb:70` asserts `assert_equal "70.0", json["weight_kg"]`; `lactic-web/lib/api/types.ts:191` declares `number` and is simply wrong |
| 3 | **Pagination is header-only**, body is a bare array: `X-Total-Count`, `X-Page`, `X-Per-Page`, `X-Total-Pages`. Only the two `exercises#index` endpoints paginate; every other index returns the full collection. | `app/controllers/concerns/paginatable.rb:10-15` |
| 4 | **Request bodies need an explicit root key** — `ParamsWrapper` is off (no `wrap_parameters.rb`, default `format: []`). So `{"set_log": {…}}`, `{"workout_session": {…}}`, `{"exercise_log": {…}}`, `{"user": {…}}`. Top-level exceptions: everything on `AuthController`, `coach/client_invitations#create`, `coach/workout_templates#create`/`#apply`, `coach/workouts#duplicate`. | strong-param calls throughout `app/controllers/api/v1/**` |
| 5 | **`WorkoutExercise.position` is a `String`** — a single uppercase letter `A`–`Z`, unique per workout. `Week.position` and `SetLog.position` are `Int`. | `app/models/workout_exercise.rb:7`; `db/schema.rb:276` |
| 6 | **Three error envelopes:** `{"error": String}`; `{"errors": [String]}` (only `RecordInvalid` → 422); `{"error": String, "code": "client_limit_reached"}` (only the coach 402). Decode as an enum. | `app/controllers/concerns/error_handling.rb:5-15` |
| 7 | **List and detail Exercise differ by key *absence*, not null** — `description`, `instructions`, `locale`, `secondary_muscles` are missing from list rows. And `secondary_muscles` entries have no `region` while `primary_muscle` does. | `app/blueprints/exercise_blueprint.rb:59-79` |
| 8 | **Two different `user` shapes.** `POST /auth` and `/auth/dev_login` hand-build a 4-key object with **no `avatar_url`**; `GET /me` returns the 5-key `UserBlueprint`. | `app/controllers/api/v1/auth_controller.rb:61-63` |
| 9 | **`program_assignment_id` is write-only.** `WorkoutSessionBlueprint` never serializes it, but `POST /client/workout_sessions` requires it. Get it from `assignment_id` on `GET /client/programs/:id` and remember it locally. | `app/blueprints/workout_session_blueprint.rb:3` |
| 10 | **`volume_sets` is a dynamic-key dictionary** `[String: Int]` whose keys are localized and summed across colliding vocabularies. | `app/models/workout.rb:14-20` |

### API shape the client app actually consumes

- **Auth.** `POST /auth` `{provider: "apple"|"google", id_token, invitation_token?}` → `{access_token, refresh_token, user}`. Access token is HS256 with payload `{user_id, exp}`, **TTL 15 min**; the refresh token is *not* a JWT but an opaque `SecureRandom.hex(32)`, **TTL 30 days**, and **rotates on every refresh** — the old row is destroyed, so two concurrent refreshes hard-fail one of them. No endpoint returns an expiry field; derive it from the JWT `exp`. `DELETE /auth` needs no auth and always returns 204. (`app/services/jwt_service.rb:2-4`, `app/services/auth/refresh.rb:9-16`)
- **401 is indistinguishable** between expired and malformed (`{"error":"Unauthorized"}` for both), so any 401 means "try refresh once".
- `GET /client/programs` returns **only `status: "active"`** assignments. `GET /client/programs/:id` takes the **program** id (not the assignment id) and is the one client endpoint returning ISO-8601 dates.
- `weeks[].workouts[]` is always the **default** `WorkoutBlueprint` view — `workout_exercises` never appears there, so opening a workout is always a second fetch (`GET /client/workouts/:id`).
- `POST /client/exercise_logs` reads `params[:exercise_log][:workout_session_id]` directly before strong params; **omit it and you get a `NoMethodError` → 500**, not a 400. Its response carries neither `set_logs` nor `workout_session_id`.
- `set_logs` has a **unique index on `(exercise_log_id, position)`**, so a duplicate retry fails 422 rather than double-inserting — useful natural idempotency for the outbox (see below).
- `GET /client/exercises/:id/history` returns a **flat `SetLog[]`** ordered by session date desc then position — with no dates and no session reference, so it cannot be grouped by session.
- **Animations** (`GET /api/v1/exercises/:id/animation`) require the `Authorization` header, proxy raw `image/gif` bytes server-side (the provider key never leaves Rails), and send `Cache-Control: private, no-store`. Each fetch costs provider quota. An upstream 401 is deliberately mapped to **502, never 401**, so it cannot trigger a token refresh. Check `has_animation` first; `animation_url` is a **relative** path.
- **Locale** resolves `users.locale` → `Accept-Language` → `"en"`, locales are exactly `en`/`it`, and there is **no query param**. `PATCH /me` permits only `name` and `avatar_url` — **there is no API to persist `users.locale`**, so `Accept-Language` is the app's only lever today.
- `GET /client_invitations/:token` is **unauthenticated and unredacted**, and returns 200 for accepted/revoked/expired invitations too — the client must branch on `status` itself.
- `AuthController` does **not** include `ErrorHandling`, so a `RecordInvalid` during first-time user creation escapes as a plain **500 with a non-JSON body**. The client must survive that.

### Sign-in: Google now, Apple at the App Store gate

**Now — Google Sign-In** (`GoogleSignIn-iOS` via SPM), plus `dev_login` kept
behind `#if DEBUG` for local work. `AuthService` is built around an
`AuthProvider` protocol so Apple slots in later without reshaping anything.

The one thing to settle empirically at implementation time: **what `aud` the iOS
ID token actually carries.** `Auth::GoogleVerifier` checks exactly one audience,
`GOOGLE_CLIENT_ID`, today the web client (`google_verifier.rb:5-6`).
Configuring `GIDConfiguration` with `serverClientID` set to that same web client
id is the documented way to make the ID token's `aud` the *server* id rather
than the iOS one — if that holds, **no backend change is needed at all**. Decode
the first real token and check before assuming either way; the fallback is
widening the verifier to a `GOOGLE_CLIENT_IDS` list, which is a small change.

Also needed now, because real sign-up starts creating users:
`AuthController` does not `include ErrorHandling`, so a `RecordInvalid` on
first-time user creation escapes as a plain 500 with a non-JSON body.

**Later — Sign in with Apple, and it is a hard release gate.** App Store
guideline 4.8 requires an equivalent privacy-preserving option once Google is
offered, so a Google-only build is a rejection risk. A Release build also has no
`dev_login` to fall back on (`config/routes.rb` guards it to dev/test). SIWA must
land before any external TestFlight or submission. Its blockers, parked:

1. **`Auth::AppleVerifier` accepts exactly one audience** (`apple_verifier.rb:6`). A native SIWA ID token's `aud` is the **app's bundle ID**, and there will be two. It must accept a list.
2. **Apple "Hide My Email" permanently locks an invited client out.** `ClientInvitations::Accept` requires an exact normalized match between invited and provider email (`accept.rb:24-44`); a `@privaterelay.appleid.com` address can never match. Needs an explicit product rule, not a silent failure.
3. `AppleVerifier` never reads Apple's name, deriving one from the email (`apple_verifier.rb:11`) — and Apple returns the real name **only on first authorization**, so it must be forwarded and used or it is lost forever.

### Product findings from the web to keep — or deliberately exceed

- **Resume-in-progress is mandatory.** The workout screen looks for an incomplete session and rehydrates its `exercise_logs`/`set_logs`; the web comment records that state used to live only in React and a refresh stranded logged sets (`lactic-web/app/client/workouts/[id]/page.tsx:48-92`). On iOS, mid-workout termination is routine.
- **Never POST a set of zeros** — a new set is pre-filled from the coach's target because the server 422s on `reps <= 0` (`page.tsx:139-153`).
- **Exercise logs are created lazily** — the first set for an exercise POSTs `/client/exercise_logs`, then `/client/set_logs` references it. That dependency is exactly what the outbox must model.
- **Rest timer today is minimal**: manual start only, `setInterval`, no sound, haptics, background continuation or wake lock, and it dies on unmount. Coach defaults are `rest_seconds: 90`, `sets: 3`, `reps: 10`.
- **The web never built** session notes, per-exercise notes, or execution photos, though the API supports all three and `AGENTS.md` §4.1 lists them as client features. History detail renders `Exercise #<id>` because the session serializer carries no exercise name, and the exercise-history screen has no inbound link at all.
- **Dark mode is deliberately absent on the web** — a starter `prefers-color-scheme` block once made mid-workout inputs unreadable (`lactic-web/app/globals.css:15-36`). iOS users expect dark mode, so build it properly rather than mirroring light-only.
- **Palette to port** (light): surface `#FAFAFA`, card `#FFFFFF`, border `#E4E4E7`, text `#18181B` / `#71717A` / `#A1A1AA`, accent `#18181B`, danger `#DC2626`, success `#15803D`, warning `#A16207`, info `#1D4ED8`. Radii 6/8/pill.
- **Invitation links point at the web** (`${FRONTEND_URL}/invite/<token>`) and `lactic-web/public/` has **no** `apple-app-site-association`, so Universal Links need a separate web change plus the Apple Team ID.
- **Telemetry may carry only `{id, role}`** — never email or name, because client records are real gym members' PII.

### Environment

- Xcode 26.6 / Swift 6.3. Installed simulator runtimes are **iOS 26.5 and 27.0 only** — an iOS 18 deployment target builds fine, but testing *on* iOS 18 needs that runtime downloaded.
- Building against the iOS 26 SDK means both apps pick up Liquid Glass on iOS 26+ devices while still running on iOS 18, provided iOS 19+ APIs stay behind `@available`.
- `xcodegen 2.44.1`, `swiftlint 0.65.1`, `swiftformat 0.62.1` installed; `tuist` is not.
- `gh` and `railway` are both authenticated as of 2026-09-08. `railway` needs the explicit project/environment/service IDs from `AGENTS.md` §2.4, not whatever is linked locally.
- `lactic-api` locally: gems now installed; Postgres 17 runs via brew but is **not on `PATH`** — prefix `/opt/homebrew/opt/postgresql@17/bin`.

### The real blocker is test data, not code

Confirmed by reading both databases on 2026-09-08:

| | production | local dev |
| --- | --- | --- |
| users / programs | 5 / 3 | 5 / 1 |
| exercises (catalog) | 1327 | — |
| **program assignments** | **0** | **0** |
| **workout sessions** | **0** | **0** |
| exercise logs / set logs | 0 / 0 | 0 / 0 |

**Assign → execute → log has never run once in production**, and there is nothing
to run it against locally either. Everything the client app is built on — sessions,
exercise logs, set logs, the `(exercise_log_id, position)` uniqueness the outbox
leans on, `weight_kg` round-tripping as a string — exists only in fixtures.

The coach account also has **0 linked clients and 0 pending invitations**, so even
creating an assignment by hand first requires walking the invitation flow.

This makes a local seed script a prerequisite, not a nicety, and it moves to the
front of the order of work. It is also the cheapest way to de-risk the whole
plan: the first time these endpoints are exercised in sequence should not be from
a half-built iOS app, where a failure is ambiguous between client and server.

---

## Current state (2026-09-08)

Steps 0-4 of the order of work are done. `lactic-ios` is live at
`github.com/enrico-querci/lactic-ios`, CI green, everything pushed.

**Shipped in `lactic-api`** (all merged and deployed):

- One ISO-8601 datetime format across the whole API (PR #46, `b21bee6`).
- `GET /client/exercises/:id/history` ordered by session date rather than set
  number — `Positionable`'s `default_scope` was winning over the controller's
  `order` (PR #47, `7e26e1e`).
- `bin/rails dev:seed` / `dev:unseed`, because both databases held zero
  assignments and zero sessions.
- `AGENTS.md` synced byte-identical across all three repos (PR #48 / web #26).

**Built in `lactic-ios`:**

| Area | State |
| --- | --- |
| Skeleton | Two app targets, three SPM packages, xcconfigs, Makefile, CI, README, `AGENTS.md` + `CLAUDE.md` symlink |
| `LacticCore` | Date/decimal/calendar coding, `SecureStorage` + Keychain, redacting logger, formatters — 25 tests |
| `LacticKit` | All client models, `APIClient` actor, error envelopes, header pagination, `ClientAPI`, `SessionStore` — 40 tests |
| `LacticUI` | Still a stub. Step 5. |
| App | Sign-in (dev_login), session restore, signed-in placeholder, sign-out |

CI runs lint, the package tests, and a generic-destination build of both app
targets. App-scheme tests are deliberately excluded (see Tooling and CI);
`make test` runs them locally.

Two findings worth remembering, both caught by testing rather than reading:

- `Date.ISO8601FormatStyle` **truncates** fractional seconds instead of
  rounding, so an encoder built on it cannot round-trip its own decoder — about
  half of all millisecond values drifted by 1ms. `APIDateFormat` formats the
  milliseconds explicitly.
- SwiftLint and SwiftFormat overlap on four rules and disagree on all of them
  (`trailing_comma`, `modifier_order`, `optional_data_string_conversion`,
  `static_over_final_class`). SwiftFormat owns formatting; those rules are
  disabled in `.swiftlint.yml` with the reason recorded inline.

---

## Repository layout

```text
lactic-ios/
├── AGENTS.md                    byte-identical to lactic-api / lactic-web
├── CLAUDE.md -> AGENTS.md       relative symlink (AGENTS.md §9.1)
├── README.md  Makefile  project.yml
├── .gitignore .gitattributes .swiftlint.yml .swiftformat .editorconfig
├── .github/workflows/ci.yml     job names mirroring lactic-api's ci.yml
├── Configs/
│   ├── Shared.xcconfig          IPHONEOS_DEPLOYMENT_TARGET=18.0, Swift 6 language
│   │                            mode, SWIFT_STRICT_CONCURRENCY=complete, warnings-as-errors
│   ├── Debug.xcconfig  Release.xcconfig
│   ├── Lactic.xcconfig          com.enricoquerci.lactic · iPhone
│   └── LacticStudio.xcconfig    com.enricoquerci.lacticstudio · iPad,iPhone
├── Apps/
│   ├── Lactic/                  AGENTS.md · LacticApp.swift · RootView · AppEnvironment
│   │   ├── Features/{Onboarding,Home,Programs,Workout,History,ExerciseDetail,Settings}
│   │   ├── Resources/{Assets.xcassets, Localizable.xcstrings, InfoPlist.xcstrings}
│   │   └── Support/{Info.plist, Lactic.entitlements}
│   ├── LacticTests/
│   ├── LacticStudio/            AGENTS.md · Features/{Onboarding,Clients} · Resources · Support
│   └── LacticStudioTests/
└── Packages/{LacticCore, LacticKit, LacticUI}
```

`project.yml` is the source of truth; `Lactic.xcodeproj` is generated and
git-ignored, so there is no `project.pbxproj` to merge-conflict and adding a file
is a filesystem operation. Build settings live in `Configs/*.xcconfig`, not the
Xcode UI — `make project` regenerates, and a UI-only edit is lost. The README
says so plainly. Bundle IDs are a one-line change in the xcconfigs.

---

## Package design

### `LacticCore` — utilities, no dependencies

- **Date decoding** — one `.iso8601withFractionalSeconds` strategy, now that the API emits a single format (trap #1, fixed upstream). Keep a test asserting the exact string `"2026-09-08T10:07:51.048Z"` decodes, so a regression on either side is caught here as well as in the Rails suite.
- **`LenientDecimal`** — decodes `Decimal` from a JSON string *or* number, encodes as a number (trap #2).
- **`CalendarDate`** — `"YYYY-MM-DD"` value type for `ProgramAssignment.start_date`.
- `JSONCoding` — shared decoder/encoder with `.convertFromSnakeCase` plus the two above.
- `KeychainStore` — `kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlock` so a background refresh works before first unlock.
- `AppLog` — `os.Logger` categories (`auth`, `network`, `outbox`, `ui`) with redaction so tokens and emails never reach a log.
- `Formatters` — mirrors `lactic-web/lib/utils/format.ts`: `en→en_US`, `it→it_IT`, date, date-time, `formatDuration` (`"{m}min"` under an hour, else `"{h}h {m}min"`), weekday names for `day 1…7`.

### `LacticKit` — models, networking, session

```
Sources/LacticKit/
├── Models/      User, AuthUser (4-key), AuthSession, Program, Week, Workout,
│                WorkoutExercise, ExerciseSummary, ExerciseDetail, MuscleRef,
│                EquipmentRef, ExerciseTaxonomy, ProgramAssignment,
│                WorkoutSession(+Extended), ExerciseLog, SetLog,
│                ClientInvitation, Subscription, WorkoutTemplate
├── Networking/  APIClient (actor), Endpoint, Page<T>, APIError, RailsWrapped,
│                APIConfiguration (baseURL, locale provider)
├── Auth/        AuthService, TokenStore, SingleFlightRefresher,
│                GoogleSignInProvider (GoogleSignIn-iOS, SPM) — now
│                AppleSignInProvider (AuthenticationServices) — App Store gate
├── Client/      ClientAPI    — programs, workouts, exercises + history,
│                               workout_sessions, exercise_logs, set_logs, account
├── Coach/       CoachAPI     — clients, invitations, exercises, taxonomy,
│                               programs/weeks/workouts, templates, assignments, subscription
└── Session/     WorkoutRecorder, SessionStore, Outbox
```

- `APIClient` is an `actor`. Every request sends `Content-Type: application/json`, `Accept-Language: <en|it>` from the **app's** locale (not the device's), and `Authorization: Bearer …` when present. On 401 it awaits the **single-flight** refresher, replays **once**, then signs out — matching `lactic-web/lib/api/client.ts:128-157`. Refresh-token rotation makes serializing this mandatory, not just tidy.
- `APIError` decodes all three envelopes and exposes `status`, `path`, `message`, `code`. 4xx is routine; ≥500 (and a non-JSON body from `AuthController`) is reportable.
- `Page<T>` is built from a bare array plus the four headers, with the web's fallbacks.
- **`WorkoutRecorder`** implements decision #3:
  - Every user action mutates an `@Observable` session **and** appends a `PendingOperation` to a disk-backed `Outbox` (atomic JSON write in the app container, excluded from backup) **before** any network call — a force-quit or dead signal loses nothing.
  - Operations: `createExerciseLog`, `createSetLog`, `updateSetLog`, `deleteSetLog`, `updateSession`, each with a client-generated `LocalID` and a `LocalID → ServerID` resolution table, so a `createSetLog` waits on its parent `createExerciseLog`.
  - Drains **serially per exercise log** with exponential backoff; resumes on launch and on `NWPathMonitor` reachability.
  - Retry safety leans on the server's own `(exercise_log_id, position)` unique index: an ambiguous `createSetLog` retry surfaces as a 422 rather than a duplicate row, which the outbox reconciles by re-reading the session. Non-retryable 4xx are surfaced, never silently dropped.
  - A non-blocking "syncing · N pending" indicator.

### `LacticUI` — design system + shared components

The web has no design system to port (two CSS variables and stock Tailwind), so
`LacticUI` defines one from the palette above with a real dark mode via semantic
asset-catalog colors. SF Pro for text; **monospaced digits** for the timer and
set inputs.

Components: `LacticButton` (primary/secondary/danger × sm/md), `LoadingView`,
`EmptyStateView`, `ErrorStateView` (message + Retry — the web's rationale is that
gym wifi fails routinely and a blank page is indistinguishable from "no
programs"), `ErrorBanner`, `StatusBadge`, `VolumeChip`, `NumericField`,
`RestTimerView`, `AnimatedExerciseImage`.

`AnimatedExerciseImage` renders the authenticated GIF with **ImageIO**
(`CGAnimateImageDataWithBlock`) — no third-party image library — behind an
on-demand toggle, with its own memory+disk cache **because the endpoint sends
`no-store` and every fetch costs provider quota**. It distinguishes 404
("no animation") from 503 (quota, retryable) from 502 (upstream).

Full Dynamic Type, VoiceOver labels, and ≥44 pt hit targets on every set-log
control — they are tapped with chalky hands, mid-set.

---

## Lactic — client app, screen by screen

| Screen | API | Notes |
| --- | --- | --- |
| **Sign in** | `POST /auth`, `POST /auth/dev_login` | **Now:** Google Sign-In via `GoogleSignIn-iOS`, handing the ID token to `POST /auth {provider: "google", id_token}`; plus a `#if DEBUG` `dev_login` field for local work. **Later (release gate):** Sign in with Apple via `ASAuthorizationAppleIDProvider` behind the same `AuthProvider` protocol — guideline 4.8 makes it mandatory once Google ships. |
| **Invitation onboarding** | `GET /client_invitations/:token`, `POST …/accept` | Mirrors `lactic-web/app/invite/[token]/page.tsx`: unauthenticated preview of coach name + invited email, then four branches (non-pending → explain; signed in + match → Accept; signed in + mismatch → name both addresses, offer sign-out; signed out → sign in carrying the token). Entered by pasted link/code **and** by `onOpenURL` / `NSUserActivity` once Universal Links exist. |
| **Home** | `GET /client/programs`, `GET /client/workout_sessions`, `GET /client/programs/:id` | Same IA as `app/client/page.tsx`: resume card first, then current program, "up next" (first workout by week `position` then `day` not among completed sessions), then the last 3 sessions. Note the programs list is already filtered to `active`. |
| **Programs / detail** | `GET /client/programs`, `GET /client/programs/:id` | Weeks by `position`, workouts by `day`, volume chips, status badge. Carries `assignment_id` forward and **persists it** — the session serializer never returns it. |
| **Workout execution** | `GET /client/workouts/:id`, `GET/POST/PATCH /client/workout_sessions`, `POST/PATCH /client/exercise_logs`, `POST/PATCH/DELETE /client/set_logs` | The core screen. Resume detection, exercise cards ordered by the `A`–`Z` position, target line (`sets × reps`, RIR, suggested weight, coach notes), "last time" assist, on-demand animation, set rows, unbounded extra sets, session completion. All writes go through `WorkoutRecorder`; new sets pre-fill from the coach's target, never zeros. |
| **Rest timer** | — | Deadline-based (store the end `Date`; never trust a ticking timer), **auto-start on set completion** with the per-exercise `rest_seconds` (90 default), plus haptics, an optional sound, a scheduled `UNNotificationRequest` so it fires when backgrounded, and `isIdleTimerDisabled` while a session is active. A Live Activity is the natural follow-up and is listed as optional. |
| **History / detail** | `GET /client/workout_sessions`, `GET /client/workout_sessions/:id` | Sorted client-side by `started_at` desc. Resolves exercise names by cross-referencing the workout rather than rendering `Exercise #<id>` as the web does. |
| **Exercise detail** | `GET /client/exercises/:id`, `…/history` | Reachable from a workout row *and* from history — the web has no inbound link. Localized description and instructions, muscles/equipment, on-demand animation, full weight history (flat, ungroupable — a known API limitation). |
| **Settings** | `PATCH /me`, `DELETE /client/account` | Language switcher (drives `Accept-Language`; persists to the server only if the API PR adds `locale` to `PATCH /me`), units, sign out, and account deletion behind a confirmation. |

Beyond the web and cheap because the API already supports them: **session notes
and per-exercise notes**. Execution photos need an upload endpoint (`AGENTS.md`
§8 lists object storage as future scope), so v1 ships the notes and documents the
photo gap. A client-side exercise *browse* screen is deliberately omitted — the
web has none, and there is no client taxonomy endpoint to populate filters.

## Lactic Studio — scaffold

Same three packages, with `CoachAPI` written out fully in `LacticKit` (cheap once
the models exist), but only two features built: sign-in, and a client list with
invitation create/resend/revoke in an iPad `NavigationSplitView` — including the
**402 `client_limit_reached`** path. Enough to prove the shared layer and be a
real starting point.

**Gate before Studio ships:** `AGENTS.md` §8 records that Apple guideline
3.1.3(b) only permits honoring a web subscription inside an app if the same
subscription is *also* sold via IAP there. Studio must not reach the App Store
until that is decided.

---

## Cross-repo work in `lactic-api`

### PR #46 — SHIPPED 2026-09-08

`config/initializers/blueprinter.rb` sets `datetime_format`, so every endpoint
emits one format. Merged as `b21bee6`, Railway deployment `SUCCESS`, verified
against a real production row (`Program#6.created_at` → `"2026-09-08T10:07:51.048Z"`).
Also fixed two billing tests that had left `main` red since 2026-09-01 by
hardcoding an `expires_at` that has since passed.

Remaining verification gap, if it ever matters: the check ran the deployed
commit's serializer against the production row, not a full HTTPS round-trip
through the container. `GET /api/v1/client_invitations/:token` is the only
unauthenticated endpoint carrying Blueprinter datetimes, so a single throwaway
invitation would close it.

### Timed with the iOS screen that needs it — not upfront

Each of these is small, and none blocks the client app. Doing them when the
consuming screen is built keeps the change and its consumer reviewable together.

| Change | Ships with |
| --- | --- |
| Permit `:locale` in `MeController#me_params` so the app can persist language (the column exists and is first in the resolution order; `Accept-Language` works meanwhile) | Settings screen |
| Add the exercise name to the workout-session serializer so history detail need not render `Exercise #<id>` | History detail screen |
| `include ErrorHandling` in `AuthController` — a first-sign-in `RecordInvalid` currently escapes as a plain 500 with a non-JSON body | **Google Sign-In (now)** — real sign-up starts creating users |
| `Auth::GoogleVerifier` accepting a `GOOGLE_CLIENT_IDS` list — **only if** the iOS token's `aud` proves to be the iOS client id rather than the `serverClientID`. Verify before writing it; it may be unnecessary | **Google Sign-In (now)**, if needed at all |

### PR 2 — Sign in with Apple (at the App Store gate, per decision #7)

1. `Auth::AppleVerifier` — accept a **list** of audiences (both bundle IDs) from `APPLE_CLIENT_IDS`/credentials, and use Apple's first-authorization `name` when the client forwards it, falling back to today's behavior.
2. **Private-relay policy.** Recommended: reject an `@privaterelay.appleid.com` address at invitation acceptance with a clear message telling the client to re-run Sign in with Apple and choose "Share My Email". No silent failure, and no weakening of the exact-match invariant `AGENTS.md` §9.1 requires preserved.

Minitest coverage for each, then `bin/rails test`, `RUBOCOP_CACHE_ROOT=tmp/rubocop bin/rubocop`, `bin/brakeman --no-pager`, `bin/bundler-audit`, `bin/rails zeitwerk:check`. Env-var **names** only in code and docs — never values.

## Considered and declined: GraphQL + apollo-ios

Worth recording, because the two problems that prompted the question are the two
GraphQL does **not** solve:

- **Dates.** GraphQL has no built-in date scalar; you define a custom `DateTime` scalar and choose its serialization yourself. If the resolver still returns `Time#to_s`, the wire format is unchanged. The real fix is "pick one format" — PR 1 item 1, either way.
- **Offline.** apollo-ios ships a normalized *read* cache but **no offline mutation queue**. The requirement here is domain-specific regardless: an ordered outbox where `createSetLog` blocks on its parent `createExerciseLog`'s server id and replays after a force-quit. That code gets written either way.
- **What it would fix:** over-fetching and round trips (Home is 3 requests; `weeks[].workouts[]` omits `workout_exercises`, forcing a second fetch). Real but modest — those calls parallelize, and a purpose-built `GET /client/home` is an afternoon if it ever hurts.
- **What it would cost:** `graphql-ruby` schema, resolvers, per-field authorization and N+1 batching in Rails, *while keeping REST alive* for the deployed `lactic-web`. Plausibly larger than the entire iOS networking layer, against `AGENTS.md` §9.1's "prefer the simplest v1 implementation".
- **Revisit at:** Studio's program builder — deeply nested, variable-shape reads are GraphQL's actual sweet spot. If the appeal is mainly a typed, drift-proof contract, an OpenAPI spec over the existing REST API plus Swift codegen buys that far more cheaply.

## Documentation

- Root `AGENTS.md`, **byte-identical** to the other two, with the edits below applied and copied back to `lactic-api` and `lactic-web` in the same change; `CLAUDE.md` a relative symlink to it:
  - §6.1 minimum target `iOS 26+` → **`iOS 18.0+`**, and the section rewritten to describe the real layout, packages, XcodeGen and validation commands.
  - §1 product table: Lactic moves from "Product target" to reflecting the app existing.
  - §3.2 `Exercise`: replaced with the real normalized catalog (`exercise_translations`, `exercise_muscles`, `exercise_equipment`, `exercise_media`, `muscles`, `equipment`) — the current text still describes only the legacy flat `muscle_group`/`video_url` shim.
  - A new ADR for the iOS project's structural choices (XcodeGen source of truth, persisted session buffer).
- Nested `Apps/Lactic/AGENTS.md` and `Apps/LacticStudio/AGENTS.md` for target-specific rules, following the `lactic-api/app/AGENTS.md` precedent.
- `README.md` — setup, `make` targets, the local-API + `dev_login` loop, and environment **names** only.
- `docs/ios-plan.md` — this file, following the `lactic-api/docs/` precedent for a plan that should outlive the conversation that produced it.

## Tooling and CI

`Makefile`: `project`, `build`, `test`, `lint`, `format`, `clean`.
`.github/workflows/ci.yml` on macOS with job names mirroring `lactic-api`:
`lint` (swiftlint + `swiftformat --lint`) and `test` (`swift test` per package,
then a generic-destination build of both app schemes).

**App-scheme tests are deliberately excluded from CI for now.** They need a
booted simulator, which is slow and couples the pipeline to whichever iOS
runtimes the runner image ships — the first CI run failed on exactly that, plus
a hardcoded `DEVELOPER_DIR` that did not exist on the runner. The package tests
hold 58 of the 59 assertions and run on the host in under a second, so the loss
is small. `make test` runs the full set locally. To re-enable, resolve a device
UDID from `xcrun simctl list devices available` and pass
`DESTINATION="platform=iOS Simulator,id=<udid>"`.

Dependabot for GitHub Actions and Swift packages, matching the API repo.

---

## Order of work

0. ~~`lactic-api` datetime fix~~ — **DONE**, PR #46, deployed and verified.
1. **Local seed data in `lactic-api`** (`db/seeds.rb` or a rake task): a coach, an accepted client, a program with weeks/workouts/exercises drawn from the real 1327-row catalog, an active assignment, and one completed session with set logs. Then **walk the whole flow by hand with `curl`** against a local server before any Swift touches it, so the endpoints are known-good in sequence and a later failure is unambiguously the client's fault.
2. Finish the repo skeleton: the `GENERATE_INFOPLIST_FILE` one-liner, `AGENTS.md` + `CLAUDE.md` symlink, `README.md`, `Makefile`, CI — then **`make project && make build && make test` green before writing any feature**, and a first commit.
3. `LacticCore` + `LacticKit` models and `APIClient`, with Swift Testing coverage for every remaining trap against fixture JSON captured from step 1's real responses.
4. ~~Auth: Keychain store, single-flight refresh, `dev_login`~~ — **DONE**. `SessionStore` is `@MainActor @Observable` and conforms to `TokenProviding`; refresh is coalesced through a single `Task`, proven by a test where eight concurrent callers produce exactly one `/auth/refresh` request. Storage is behind a `SecureStorage` protocol so tests use memory rather than an unsigned host keychain.
5. `LacticUI` design system.
6. Client app: Home → Programs → Workout execution (with `WorkoutRecorder`) → History → Exercise detail → Settings.
7. Rest timer, notes, localization (`.xcstrings`, en + it — ~150 client-facing keys, mirroring `lactic-web/lib/i18n/messages/en.ts` namespaces).
8. **Google Sign-In** — Google Cloud iOS OAuth client, `GIDClientID` + reversed-client-id URL scheme in `Info.plist`, `GoogleSignInProvider`, and `POST /auth`. Decode the first real ID token and check its `aud` before deciding whether `Auth::GoogleVerifier` needs widening. `include ErrorHandling` in `AuthController` ships with this.
9. **Invitation onboarding** — now testable, because it needs a real signed-in identity and Google provides one. Manual code/link entry plus the `onOpenURL` handler; Universal Links stay deferred (they need an Apple Team ID and an `apple-app-site-association` file on `lactic-web`).
10. `LacticStudio` scaffold with `CoachAPI`.
11. `AGENTS.md` sync back to `lactic-api` and `lactic-web`, including §2.5's "last verified production state" (stale — still points at `e9baae8` / 2026-08-24).

**Deferred to the App Store gate** (decision #7): Sign in with Apple and
`lactic-api` PR 2, plus Universal Links, which need an Apple Developer team
either way. Nothing before that point is blocked by them.

> **Scope note.** Bringing invitation onboarding back in (step 9) follows from
> decision #7 rather than being a separate expansion: it was deferred only
> because it "needs a real signed-in identity to be worth testing", and Google
> Sign-In supplies exactly that. It also matters more than it looks — a client
> account can *only* come into existence by accepting an invitation, and
> production currently has zero linked clients, so without it the client app has
> no way to onboard anybody new. Say so if you would rather it stayed out.

## Verification

- `make lint && make test` green; `xcodebuild build` green for both schemes.
- **End-to-end against a local backend** — the highest-value check, and why `dev_login` matters: run `bin/rails server` in `lactic-api` against the step-1 seed, point the app at `http://localhost:3000`, then sign in, open a program, start a session, log and edit sets, add an extra set, complete the session, and confirm the rows in Postgres. The dev database is otherwise empty (0 assignments, 0 sessions), so this check is worth nothing without the seed.
- **Offline proof:** start a session, cut the simulator's network, log several sets, force-quit, relaunch, restore the network, and confirm every set arrives exactly once with correct positions.
- **Localization proof:** switch to Italian and confirm exercise names, instructions, muscle/equipment glossary and `volume_sets` keys come back translated.
- Simulator screenshots of each screen via the `device-interaction` skill; Dynamic Type at XXL and a VoiceOver pass on the workout screen.
- `lactic-api` PR: the five commands listed above, all green.

## Not in scope

Studio's program builder, exercise picker, templates, assignments and billing;
execution photos (no upload endpoint); a client exercise-browse screen; HealthKit;
watchOS; widgets; push notifications; Live Activities (the natural follow-up to
the rest timer).

Also deferred to the App Store gate (decision #7): Sign in with Apple and
Universal Links. Google Sign-In and invitation onboarding are **in** scope now.

**Prerequisites that need the user.**

- **Now, for step 8:** a **Google Cloud iOS OAuth client** for `com.enricoquerci.lactic` (and later `com.enricoquerci.lacticstudio`). I need its client id and reversed client id; the existing web `GOOGLE_CLIENT_ID` is also needed as the `serverClientID`.
- **At the App Store gate:** an Apple Developer team plus two App IDs with the Sign in with Apple capability — also what unblocks Universal Links.
- `gh` and `railway` are already authenticated as of 2026-09-08.

Nothing blocks running on the simulator today: steps 1–7 need none of the above,
since `dev_login` covers local development.
