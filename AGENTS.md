# AGENTS.md — Lactic & Lactic Studio

> Root project context for every Lactic repository.
>
> It documents the product, current implementation, architecture, deployments,
> conventions, and cross-repository rules. Platform-specific instructions may
> live in nested `AGENTS.md` files.
>
> Keep this file byte-for-byte identical across all Lactic repositories.
> `CLAUDE.md` should be a relative symlink to this file.

---

## 1. Project Overview

**Lactic** (**L**egs **A**re **C**ausing **T**remendous **I**nternal **C**ramping)
is a workout-management ecosystem for coaches and their clients.

| Product | Audience | Platform | Purpose | Current state |
| --- | --- | --- | --- | --- |
| **Lactic** | Client | iOS and Android | Follow assigned programs and log workouts | Core flows implemented; visual redesign landed through `lactic-ios#1`-`#5`; see `docs/ios-plan.md`. The Android app matches iOS (`lactic-android#6`-`#8`) |
| **Lactic Studio** | Coach/Admin | Web, iPad-first iOS, and tablet-first Android | Manage clients and create training programs | Coach routes (`/coach/**`) are deployed on the web; the native apps match them (`lactic-ios#13`-`#16`, `lactic-android#3`-`#5`) except buying a plan, which stays on the web |
| **Lactic Web** | Coach and client | Web | Browser access to both role-specific experiences | Implemented and deployed |
| **Lactic API** | All clients | Rails API | Shared auth, business logic, persistence, email, and REST API | Implemented and deployed |

**Lactic Studio** names the coach/admin dashboard as a product, independent of which
surface currently implements it — the coach routes inside Lactic Web and the native
iPad-first app offer the same features, except that a plan is bought only on the web
(the app shows it read-only; see §8). Coaches are the paying customer, so Lactic Studio is expected to be the
primary source of revenue; weigh coach-side work accordingly when prioritizing.

**Reference competitor:** CoachPlus (client) / CoachPlus PT (admin).

### 1.1 Current milestone

The latest completed milestone is Lactic Studio subscription billing via RevenueCat:

- Coach signup is open — any Google or Apple identity becomes a coach on
  first sign-in, starting on a free plan capped at 3 clients.
- Four paid tiers (Pro, Pro+, Unlimited, and an unlisted Founding offer) raise
  or remove that cap. Billing runs through RevenueCat's Web Billing product;
  a coach subscribes through an SDK-embedded checkout on `/coach/billing`,
  not a redirect to an external page.
- A RevenueCat webhook keeps each coach's stored plan in sync, but access
  always re-derives from the plan's own expiry rather than a stored status —
  a missed or delayed webhook self-heals instead of granting access forever.
- A lapsed subscription drops a coach to the free plan's limit but never
  touches their existing clients' programs or history — only new client
  invitations are blocked until the coach is back under the cap or
  resubscribes.
- `COACH_EMAILS` no longer gates account creation (see §2.3). It is now an
  unlimited comp list: a listed email is never capped regardless of billing
  state, independent of whatever RevenueCat reports.
- Both backend and frontend changes are merged, deployed, and online.

### 1.2 Current iOS milestone

As of **2026-09-13**, the iOS repository has completed and merged six visual
implementation increments, landed in order:

1. `lactic-ios#1` (`codex/lactic-visual-foundation` onto `main`) establishes
   the shared chalk/graphite/electric-lime palette, system-font hierarchy,
   reusable controls and states, sign-in treatment, contrast tests, and the
   initial Lactic Studio brand scaffold.
2. `lactic-ios#2` (`codex/workout-execution-design` onto `#1`) turns workout
   execution into the primary training surface: overview hierarchy, exercise
   cards, logged and extra-set controls, notes, previous-performance context,
   rest timer, screen-awake behavior, and local rest alerts. Notification
   cleanup uses the async API so the warnings-as-errors Release build passes.
3. `lactic-ios#3` (`codex/home-dashboard-design` onto `#2`) turns Home into an
   action-first dashboard: the newest unfinished session is resumable directly,
   otherwise the next workout can be started directly; programme progress,
   coach guidance, prescription counts, completed-session history, pull to
   refresh, and a branded empty state follow beneath it.
4. `lactic-ios#4` (`codex/programme-browsing-design` onto `#3`) redesigns active
   programme browsing and plan detail with assignment context, coach guidance,
   week/workout hierarchy, volume summaries, and session-derived upcoming,
   in-progress, and completed states. Synthetic DEBUG fixtures cover both the
   list and detail without authentication or live API data.
5. `lactic-ios#5` (`codex/history-progress-design` onto `main`) redesigns History,
   completed-session summaries, and exercise progress with lifetime metrics,
   workout and exercise names, performed-set volume, grouped recent sessions,
   personal bests, and a best-weight trend chart. The additive API context ships
   in `lactic-api#51`; optional decoding plus a workout fallback keeps rolling
   deployment safe.
6. `lactic-ios#6` (`codex/studio-client-ui` onto `main`) replaces the native
   Lactic Studio placeholder with a polished coach sign-in and an iPad-first
   Clients/Invitations `NavigationSplitView`. It supports inviting, resending,
   and revoking, distinguishes full-plan, rejected, and offline failures, shows
   live client capacity, and ships complete English/Italian localization. A
   DEBUG-only fixture transport covers normal, full-plan, and sign-in states
   without authentication or a live API. `ClientListModel` refreshes capacity
   after a successful invitation so the UI never derives billing state itself.

Sign in with Apple then landed for both apps in `lactic-ios#7`, with its
backend in `lactic-api#59` (see §2.3). Both sign-in screens and the invitation
screen offer Apple beside Google, which clears App Review guideline 4.8, and
the development sign-in forms are gone; UI tests sign in through the DEBUG
`--dev-login <email>` launch argument instead.

All six visual PRs have passing GitHub lint/test checks. The client and Studio Debug
schemes, the Lactic Release configuration, and all three package suites pass
locally. Home, workout, programme, history, session, and exercise-progress
fixtures plus the Studio client/invitation surfaces have been visually checked
in light and dark appearances and at accessibility Dynamic Type sizes. DEBUG-only
synthetic routes (`--workout-design-preview`, optional
`--workout-design-timer`; `--home-design-preview`, optional `--home-resume`;
`--programme-design-preview`, optional `--programme-list`; and
`--history-design-preview`, optional `--history-session` or
`--history-exercise`; plus `--studio-design-preview`, optional
`--studio-plan-full` or `--studio-sign-in`) keep that review independent of
authentication and live API data.

Native Lactic Studio then reached parity with the web's coach routes in
`lactic-ios#13`-`#16`: LacticKit models for every coach screen (#13); a shell
with Assignments, client detail with session history, and a read-only Plan
(#14); programmes, the week/workout builder, the workout editor with an
exercise picker, and templates (#15); and the exercise catalog with custom
exercises (#16). Studio also creates and applies workout templates and
duplicates workouts across weeks and days, which the web cannot. Buying a plan
stays web-only until the App Store question in §8 is decided. DEBUG
`--studio-destination <name>` and `--studio-route <route>` open any Studio
screen for review.

The next client visual sequence is Settings and remaining onboarding/account
states. Automated device taps were not
available during the client visual pass, so workout logging/deletion and client
navigation still need hands-on interaction verification even though their
models, builds, and screenshot states pass.

### 1.3 Current Android milestone

As of **2026-09-30**, `lactic-android` holds the Android counterpart of both
apps, built from the iOS code as the behavioural reference and talking to the
same production API with no backend change:

- `lactic-android#1`-`#2` lay the foundation: Gradle convention plugins, the
  design system ported from iOS tokens with contrast tests, networking with
  single-flight token refresh, the encrypted session store, Google sign-in via
  Credential Manager, the shared Profile and Settings, and DEBUG fixtures.
- `lactic-android#3`-`#5` reach Studio parity with iOS: clients, invitations
  and a read-only Plan; assignments and client detail; programmes, the
  builder, the workout editor, templates, and the exercise catalog.
- `lactic-android#6`-`#8` reach Lactic parity: Home, programmes, invitation
  onboarding (`lactic://invite/<token>` or a pasted code), workout execution
  over a Room outbox with a WorkManager backstop, the rest alert, and history
  with exercise progress.

Every screen was exercised on an API 36 emulator through DEBUG fixtures,
including adb-driven workout logging and deletion, and Studio was checked on
a Pixel Tablet emulator. Lactic also ran end to end against a local API: sets
logged offline survived process death, and WorkManager sent them once the
network returned. Still open: real Google sign-in needs an Android OAuth
client per package and signing SHA-1 in the `lactic` Google Cloud project;
the first Firebase App Distribution releases follow.

---

## 2. Architecture

### 2.1 Repositories

| Repository | Contents |
| --- | --- |
| `lactic-ios` | iOS monorepo: Lactic (iPhone client), Lactic Studio (iPad coach), and the shared `LacticCore`/`LacticKit`/`LacticUI` packages |
| `lactic-api` | Ruby on Rails API-only backend |
| `lactic-web` | Next.js web portal with coach and client routes |
| `lactic-android` | Android monorepo: Lactic (phone, client) and Lactic Studio (tablet-first, coach) with shared `core:*` and `feature:*` Gradle modules |

### 2.2 Technology stack

| Layer | Technology |
| --- | --- |
| iOS | Swift 6.x, SwiftUI, modular Swift Packages |
| Android | Kotlin 2.4, Jetpack Compose, Material 3, Hilt, Retrofit, Room, WorkManager, Gradle modules |
| Web | Next.js 16.1.6, React 19.2.3, TypeScript 5, Tailwind CSS 4 |
| Backend | Ruby 3.4.3, Rails 8.1.3.1, API-only |
| Database | PostgreSQL hosted on Railway |
| Serialization | Blueprinter |
| Authentication | Google Sign-In and Sign in with Apple; JWT access and refresh tokens |
| Transactional email | Resend HTTPS API through Action Mailer |
| Backend hosting | Railway, Dockerfile deployment |
| Frontend hosting | Vercel with Git integration |
| Storage | TBD; likely S3-compatible storage such as Cloudflare R2 |
| CI/CD | GitHub Actions, Railway Git deployment, and Vercel Git deployment |

### 2.3 Authentication and authorization

- Google and Apple are the only production sign-in methods in v1.
- There is no email/password signup in v1.
- Both iOS apps implement Sign in with Apple and Google. The web UI and both
  Android apps implement Google only. Android sign-in uses Credential Manager
  with the web OAuth client as `serverClientId`, so its ID tokens carry the
  audience the API already verifies; each package also needs an Android OAuth
  client (package name plus signing SHA-1) in the same Google Cloud project.
- A native Apple ID token's audience is the requesting app's bundle ID, so
  `Auth::AppleVerifier` accepts `com.enricoquerci.lactic` and
  `com.enricoquerci.lacticstudio` (`APPLE_CLIENT_IDS` overrides the list). It
  must never verify against a blank audience: the `apple_id` gem skips the
  `aud` check entirely when given one. It also requires `email_verified`,
  because accounts are linked by email.
- Apple sends the user's name to the app only on first authorization; the app
  forwards it as `name` on `POST /auth`, and the API uses it only when creating
  a user.
- An Apple "Hide My Email" relay address can never match an invitation's
  email. The exact-match rule stands; acceptance fails with a message telling
  the client to stop using Lactic in their Apple Account's Sign in with Apple
  settings and sign in again with Share My Email.
- The API issues short-lived JWT access tokens and refresh tokens.
- A user has exactly one role: `coach` or `client`.
- Existing users sign in normally using their linked provider identity.
- An unknown client must present a valid invitation token during social sign-in.
- Each native app sends `app` (`lactic` or `studio`) on `POST /auth`, and the
  API refuses a user that app cannot serve without creating or linking
  anything: a coach in Lactic, a client in Lactic Studio, and an email with no
  invitation in Lactic. The value only ever refuses; it never chooses a role.
  The web sends none. The apps also sign out a stored session of the wrong
  role on launch.
- Coach signup is open: an unrecognized email with no pending client
  invitation becomes a coach automatically, on the free plan. The one guard
  is that an email with a pending, unexpired client invitation cannot become
  a coach by signing in outside that invitation's link — the client must
  accept it properly instead.
- `COACH_EMAILS` no longer gates coach account creation. It is now a
  billing-independent comp list — a listed email always has an unlimited
  client cap, regardless of subscription state (see §3.2).
- Never trust a role supplied by a browser or mobile client when creating an
  account.
- Invitation acceptance requires the normalized social-provider email to equal
  the normalized invited email.
- Development/test may use `/api/v1/auth/dev_login`; that route does not exist
  in production.

### 2.4 Production infrastructure

#### Backend

- Public API: `https://lactic-api-production.up.railway.app`
- Health check: `https://lactic-api-production.up.railway.app/up`
- Railway API project: `67b6a3e9-e4d7-4aa7-b501-376f4c9cbcfb`
- Railway production environment: `9645ae12-7b8f-4c5b-8a46-950428c3c822`
- Railway API service: `5289c1bd-e10a-403f-a677-14030dabf298`
- GitHub repository: `enrico-querci/lactic-api`
- Merges to `main` trigger a Railway deployment.
- The production Docker entrypoint runs `bin/rails db:prepare` before starting
  the Rails server, so pending migrations are applied during deployment.

#### Database

- Railway database project: `2233428f-e904-4d09-ba81-6bc4d1474d49`
- Railway production environment: `5ce33fd0-5342-414a-a17a-93496eb0f1c0`
- Railway PostgreSQL service: `426d350b-0c96-48f5-bb70-3e8b27151bbf`
- The API receives its connection string through `DATABASE_URL`.

#### Frontend

- Production URL: `https://lactic-web.vercel.app`
- Vercel project: `prj_B7j9JXLQak7sH3EY0ZAGaqzjLI77`
- Vercel team: `team_rrjKNHw6fKRQhVt1Ol5lXhZp`
- GitHub repository: `enrico-querci/lactic-web`
- Merges to `main` trigger a Vercel production deployment.
- Pull requests receive Vercel preview deployments and deployment checks.

#### Email

- Provider: Resend.
- Sending domain: `yellowtulip.it` (verified).
- Expected sender: `Lactic <noreply@yellowtulip.it>`.
- Railway production variables include `RESEND_API_KEY`, `MAIL_FROM`,
  `FRONTEND_URL`, and `COACH_EMAILS`.
- Never write secret values in source, documentation, logs, issues, or commits.
  Document variable names only.

#### Billing

- Provider: RevenueCat, Web Billing product (Stripe underneath — this app is
  the merchant of record, not RevenueCat; VAT/tax handling is a business
  decision outside this codebase, not something the code assumes).
- Railway variables: `REVENUECAT_SECRET_API_KEY` (must be a **v2** API key —
  v1 keys do not work against the v2 endpoints this app calls),
  `REVENUECAT_PROJECT_ID`, `REVENUECAT_WEBHOOK_SIGNING_SECRET`.
- Vercel variable: `NEXT_PUBLIC_REVENUECAT_WEB_BILLING_KEY` — RevenueCat's
  **public** Web Billing key, safe to expose client-side; a different key
  from the backend's secret one.
- Optional everywhere: `Billing::RevenueCat::Client#configured?` gates every
  call, matching the presence-gated pattern used for Resend and Sentry —
  every coach simply reads as Free without it configured.
- Never write secret values in source, documentation, logs, issues, or
  commits. Document variable names only.

#### Sign in with Apple

- Apple Developer team `PE865UQNK4` (the `enricoquerci` App Store Connect
  account). App IDs `com.enricoquerci.lactic` and
  `com.enricoquerci.lacticstudio` both carry the Sign in with Apple
  capability.
- App Store Connect app records: Lactic `6817242451` (SKU `LACTIC-IOS`) and
  Lactic Studio `6817242889` (SKU `LACTIC-STUDIO-IOS`), both primary locale
  `en-GB`.
- Sign in with Apple key `A44BHGF86K` ("Lactic SIWA"), configured with
  Lactic's App ID as its primary. Studio's App ID is a separate primary: if
  Studio's code exchange ever fails with `invalid_client`, group it under
  Lactic in the Developer Portal. The key's `.p8` is downloadable only once;
  it lives outside every repository and is never committed.
- Sign-in itself needs no configuration: the API verifies identity tokens
  against Apple's public keys.
- Railway variables `APPLE_TEAM_ID`, `APPLE_SIGN_IN_KEY_ID` and
  `APPLE_SIGN_IN_PRIVATE_KEY` (the `.p8` key's PEM text) enable exchanging a
  sign-in's authorization code for a refresh token, which
  `DELETE /api/v1/client/account` revokes as App Review guideline 5.1.1(v)
  requires. Optional, like Resend and RevenueCat: without them both calls are
  skipped, and neither can ever fail a sign-in or a deletion.
- Never write secret values in source, documentation, logs, issues, or
  commits. Document variable names only.

#### Android distribution

- Firebase project `lactic` (Google Cloud project `235345338249`, which also
  owns the web OAuth client). Both Android apps are registered there with the
  debug and upload-key SHA-1s. No Firebase SDK ships in either app; builds are
  uploaded with the `firebase` CLI (`make distribute-studio`,
  `make distribute-lactic`).
- Firebase App Distribution is the only channel; every build goes to the
  "Lactic Testers" group (alias `lactic-testers`). Play Store publishing is
  future scope (§8).
- Release builds are signed with an upload keystore kept outside every
  repository. Its path, alias, and passwords are read from
  `~/.gradle/gradle.properties` (`LACTIC_UPLOAD_STORE_FILE`,
  `LACTIC_UPLOAD_KEY_ALIAS`, `LACTIC_UPLOAD_STORE_PASSWORD`); without them a
  release build is unsigned, which is how CI builds it.
- Never write secret values in source, documentation, logs, issues, or
  commits. Document variable names only.

#### Error tracking

- Provider: Sentry, on both `lactic-api` and `lactic-web`.
- Railway variable: `SENTRY_DSN`. Vercel variables: `NEXT_PUBLIC_SENTRY_DSN`,
  and `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` (none `NEXT_PUBLIC_`
  — build-time only, for source map upload; without them stack traces show
  minified chunk names instead of real filenames and line numbers). The
  Sentry Vercel marketplace integration provisions these three
  automatically when connected; otherwise they're created by hand from a
  Sentry auth token.
- Optional everywhere: both apps run with tracking off when the DSN is unset,
  which is how local development and the test suites run.
- Error reports carry only `{ id, role }` for the current user — never email
  or name. Client records hold real gym members' personal data, so no report
  should be able to leak it even indirectly (see `config/initializers/sentry.rb`
  for the full scrubbing rationale).

### 2.5 Last verified production state

Verified on **2026-08-24**:

| Component | Source commit | Deployment | Result |
| --- | --- | --- | --- |
| API | `e9baae8700d789e745d3f0a43ec2f6e743ad8f7e` | Railway `07541263-8c12-42ec-bb7d-29307aa96e98` | `SUCCESS`; `/up` returned HTTP 200 |
| Web | `1a0d1a59242e7de830c7f3b8aa7011f5bd618fc0` | Vercel `dpl_2tqmoPBJKsMTcVqaUxVru5VyNEe7` | `READY`; production alias verified |

Merged pull requests:

- API: `enrico-querci/lactic-api#45`
- Web: `enrico-querci/lactic-web#25`

---

## 3. Data Model

### 3.1 Core hierarchy

```text
Coach (User with role=coach)
 ├─ ClientInvitation
 ├─ Client (User with role=client)
 └─ Program (reusable template)
     └─ Week
         └─ Workout (day 1-7; multiple workouts per day allowed)
             └─ WorkoutExercise
                  └─ Exercise (global or coach-owned catalog entry)

ProgramAssignment
 ├─ Program
 ├─ Coach
 └─ Client

WorkoutSession
 └─ ExerciseLog
      └─ SetLog
```

### 3.2 Entity details

#### User / Coach

- `id`, `name`, `email`, `avatar_url`, `role`, provider identity fields.
- `apple_refresh_token` and `apple_client_id` (the bundle ID it was issued
  to), kept only so account deletion can revoke Sign in with Apple.
- Has many clients, invitations, programs, exercises, templates,
  assignments, and at most one `CoachSubscription` as appropriate.
- Coach signup is open (§2.3); `COACH_EMAILS` now only comps a listed email
  to an unlimited client cap, independent of billing state.
- `client_limit`/`client_slots_used`/`can_invite_client?` derive the coach's
  effective cap: the comp list wins if listed, otherwise the active
  `CoachSubscription`'s limit, otherwise the free plan's limit of 3.

#### User / Client

- `id`, `name`, `email`, `avatar_url`, `role`, `coach_id`.
- Belongs to a coach after accepting an invitation.
- Has many program assignments and workout sessions.

#### CoachSubscription

- `id`, `user_id` (unique — at most one row per coach), `plan_key`
  (`free`/`pro`/`pro_plus`/`unlimited`/`founding`), `entitlement_id`,
  `expires_at`, `auto_renew`, `billing_issue_at`.
- No row means Free. `active?` is derived from `expires_at` rather than a
  stored status, so a subscription that RevenueCat never told this app had
  lapsed still stops granting access on its own once the period ends.
- Written only by `Billing::SyncSubscription`, which always re-fetches from
  RevenueCat rather than trusting a webhook payload's contents — webhook
  delivery is at-least-once with no ordering guarantee.

#### RevenueCatWebhookEvent

- `id`, `event_id` (unique), `event_type`, `app_user_id`, `environment`,
  `payload`, `processed_at`.
- Idempotency ledger and audit trail for `POST /api/v1/webhooks/revenuecat`;
  the same `event_id` delivered more than once is only ever applied once.

#### ClientInvitation

- `id`, `coach_id`, `email`, `token_digest`.
- `expires_at`, `sent_at`, `accepted_at`, `revoked_at`.
- Stores only a digest; the raw token is shown only when created or regenerated.
- Secure, expiring, revocable, and single-use.
- Pending invitations can be resent or revoked by their coach.
- Acceptance requires matching social identity, links the client to the coach,
  and records `accepted_at`.

#### Program

- `id`, `coach_id`, `name`, `description`.
- Reusable template with an ordered, variable number of weeks.
- The same program can be assigned to multiple clients with different dates.

#### Week

- `id`, `program_id`, `position`.
- Contains ordered workouts.

#### Workout

- `id`, `week_id`, `name`, `day`.
- Multiple workouts may exist on the same day.
- Can be duplicated within or across weeks.
- Can be snapshotted as a standalone `WorkoutTemplate`.

#### WorkoutTemplate

- `id`, `coach_id`, `name`, `source_workout_id`.
- Reusable snapshot that can be applied elsewhere.

#### Exercise

- `id`, `name`, `muscle_group`, optional `video_url` and `thumbnail_url`.
- `is_custom` and optional `coach_id` distinguish global from coach-owned
  exercises.
- The target catalog contains approximately 150-200 common exercises.

#### WorkoutExercise

- `id`, `workout_id`, `exercise_id`, `position`.
- Target configuration: `sets`, `reps`, `rest_seconds`, optional `rir`,
  suggested `weight`, and coach `notes`.

#### ProgramAssignment

- `id`, `program_id`, `client_id`, `coach_id`.
- `start_date`, optional `notes`, and `status` (`active`, `completed`, `paused`).

#### WorkoutSession

- `id`, `client_id`, `workout_id`, `program_assignment_id`.
- `started_at`, `completed_at`, and client notes.
- History responses also serialize the associated `workout_name` so clients do
  not need an extra request just to label a session.

#### ExerciseLog

- `id`, `workout_session_id`, `workout_exercise_id`.
- Client notes and optional execution photo URL.
- Session-detail responses include the related exercise's id and localized name
  plus workout position for display and navigation.

#### SetLog

- `id`, `exercise_log_id`, `position`, `weight_kg`, and performed `reps`.
- Exercise-history responses add the workout-session id and performed date so
  flat set rows can be grouped and charted without changing persistence.

### 3.3 Computed values

- **Volume sets per muscle group:** sum configured sets across workout exercises,
  grouped through the associated exercise's `muscle_group`.
- **Estimated duration:** derived from configured sets, repetitions, and rest
  periods; exact product formula may evolve.

---

## 4. Product Features

### 4.1 Lactic client experience

| Feature | Description |
| --- | --- |
| View program | Browse assigned programs, weeks, days, workouts, and parameters |
| Execute workout | Guided workout mode with rest timer |
| Log sets | Store actual weight and repetitions per set |
| Add extra sets | Record sets beyond the coach's target |
| Notes and execution | Personal workout/exercise notes and photos |
| Coach guidance | Read coach notes and watch exercise videos |
| Progress | Review session and exercise weight history |
| Onboarding | Accept a coach invitation through social sign-in |

### 4.2 Lactic Studio coach/admin experience

| Feature | Description |
| --- | --- |
| Manage clients | List clients, inspect progress, remove links, and manage invitations |
| Create programs | Build weeks, days, workouts, and configured exercises |
| Exercise catalog | Search global exercises and create coach-owned exercises |
| Reuse workouts | Duplicate workouts and apply saved workout templates |
| Assign programs | Assign a program with start date and notes |
| Review progress | Inspect sessions, actual weights, and repetitions |
| Planning metrics | Volume sets and estimated workout duration |
| Billing | View current plan and usage; subscribe or upgrade via RevenueCat |
| Delete account | `DELETE /api/v1/coach/account`, offered in native Studio. Refused (409, `subscription_active`) while a paid plan still renews; clients keep their accounts, but the coach's programmes and the sessions logged against them go |

### 4.3 Implemented web portal

The Next.js application already contains both role-specific views.

#### Coach routes and capabilities

- `/coach/clients`: client list plus create/resend/revoke invitation CRUD.
- `/coach/clients/[id]`: individual client and progress.
- `/coach/programs/**`: program list, details, builder, weeks, workouts, and
  workout-exercise configuration.
- `/coach/exercises/**`: exercise catalog and custom exercise creation.
- `/coach/templates`: workout templates.
- `/coach/assignments/**`: program assignments.
- `/coach/billing`: current plan, usage, and subscribing/upgrading via
  RevenueCat Web Billing.

#### Client routes and capabilities

- `/client/programs/**`: assigned programs and details.
- `/client/workouts/[id]`: workout execution and set logging.
- `/client/history/**`: workout-session history and details.
- `/client/exercises/[id]`: exercise details and progress history.

#### Shared onboarding and auth

- `/login`: Google Sign-In and development login support.
- `/invite/[token]`: validates invitation metadata, carries the token through
  Google authentication, and completes onboarding.
- Role guards route coaches to `/coach` and clients to `/client`.
- The API client refreshes expired access tokens using the stored refresh token.

---

## 5. Key Flows

### 5.1 Coach creates and assigns a program

1. Coach creates a program.
2. Adds ordered weeks.
3. Adds one or more workouts to days 1-7.
4. Adds exercises with sets, reps, rest, RIR, weight, and notes.
5. Optionally duplicates workouts or applies a saved template.
6. Assigns the program to one or more clients with a start date and notes.

### 5.2 Client executes a workout

1. Client opens an active program and current week.
2. Selects the day's workout.
3. Reviews coach parameters and notes.
4. Starts the session.
5. Records weight and repetitions for each set.
6. Optionally adds sets, notes, and photos.
7. Uses the rest timer between sets.
8. Completes the session and makes it available in history.

### 5.3 Coach invites a client

1. Coach opens `/coach/clients` and submits the client's email.
2. API creates a secure invitation, stores only its digest, and sends an email
   through Resend.
3. Email links to `${FRONTEND_URL}/invite/<raw-token>`.
4. Coach may resend a pending invitation (rotating the token and expiry) or
   revoke it.
5. Client opens the link and signs in with Google or Apple.
6. Frontend sends the invitation token alongside the provider ID token.
7. API verifies token state, expiry, revocation, single-use status, and exact
   normalized email match.
8. API creates or links the client, assigns the coach, marks the invitation
   accepted, and returns JWT tokens.
9. Frontend routes the client into the client experience.

### 5.4 First-time coach onboarding

1. User signs in through Google or Apple, with no invitation token.
2. API verifies provider identity; unless that email has a pending, unexpired
   client invitation, it creates a `coach` user. No browser-supplied role is
   consulted.
3. The new coach starts on the free plan (3 clients) with no
   `CoachSubscription` row.
4. The coach can subscribe from `/coach/billing` at any time (§5.5), or an
   operator can add their email to `COACH_EMAILS` to comp them an unlimited
   cap regardless of billing state.

### 5.5 Coach subscribes to a paid plan

1. Coach opens `/coach/billing`; the web app fetches
   `GET /api/v1/coach/subscription` for their current plan and usage, and
   `purchases.getOfferings()` (RevenueCat Web Billing SDK) for the plan cards.
2. Coach picks a plan; `purchases.purchase()` renders an embedded checkout in
   the page — not a redirect — and resolves once payment completes.
3. Web app calls `POST /api/v1/coach/subscription/sync`, which fetches the
   coach's entitlements from RevenueCat directly and upserts
   `CoachSubscription`, so the new limit applies immediately rather than
   waiting on webhook delivery.
4. RevenueCat also calls `POST /api/v1/webhooks/revenuecat` (signature- or
   shared-secret-verified, no JWT) for every lifecycle event thereafter —
   renewal, cancellation, billing issue, expiration. The handler re-fetches
   from RevenueCat rather than trusting the event payload, and is idempotent
   per `event_id`.
5. If a subscription lapses, the coach's `CoachSubscription` naturally reads
   as inactive once `expires_at` passes — no explicit cancellation webhook is
   required for access to stop. Existing clients and their data are
   unaffected; only new client invitations are blocked
   (`Api::V1::Coach::ClientInvitationsController` returns 402) until the
   coach is back under their plan's limit or resubscribes.

---

## 6. Development Conventions

### 6.1 iOS (`lactic-ios`)

- Swift 6 language mode with complete concurrency checking, and SwiftUI.
- **Minimum target: iOS 18.0.** Built against the iOS 26 SDK, so both apps
  adopt Liquid Glass on iOS 26+ devices while still running on iOS 18 —
  every iOS 19+ API must stay behind an `@available` check.
- Architecture: SwiftUI with `@Observable` and async/await. No third-party
  architecture framework; the only external dependency is GoogleSignIn-iOS.
- One Xcode project, two app targets: **Lactic** (iPhone, client) and
  **Lactic Studio** (iPad-first, coach). Bundle ids `com.enricoquerci.lactic`
  and `com.enricoquerci.lacticstudio`.
- Shared local Swift packages under `Packages/`:
  - `LacticCore`: utilities, extensions, constants, coding helpers.
  - `LacticKit`: models, networking, API client, auth, session persistence.
  - `LacticUI`: design system and shared UI components.
- **`project.yml` is the source of truth**; `Lactic.xcodeproj` is generated by
  XcodeGen and git-ignored. Build settings belong in `Configs/*.xcconfig`, not
  the Xcode UI, because a regenerate discards UI-only edits.
- PascalCase types and camelCase members.
- Tests use Swift Testing (`@Test` / `#expect`), not XCTest.
- The full implementation plan lives in `docs/ios-plan.md`.

Relevant validation commands:

```bash
make project   # regenerate Lactic.xcodeproj after pulling or editing project.yml
make build     # both app schemes, iOS Simulator
make test      # package tests on the host, then both app schemes
make lint      # swiftformat --lint and swiftlint
```

### 6.2 Rails (`lactic-api`)

- Ruby 3.4.3 and Rails 8.1.x API-only.
- REST JSON endpoints are versioned under `/api/v1/`.
- Follow conventional Rails snake_case naming.
- PostgreSQL via Active Record.
- Blueprinter serializers.
- Minitest test suite with fixtures.
- JWT access and refresh tokens.
- Use service objects for flows such as authentication and invitation acceptance.
- Local API default: `http://localhost:3000`.

Relevant validation commands:

```bash
bin/rails test
RUBOCOP_CACHE_ROOT=tmp/rubocop bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
bin/rails zeitwerk:check
```

### 6.3 Web (`lactic-web`)

- Next.js App Router with TypeScript and React.
- Tailwind CSS for styling.
- Keep role-specific pages under `app/coach` and `app/client`.
- Keep typed API calls under `lib/api/endpoints`.
- Shared authentication state lives in `lib/auth/context.tsx`.
- Local web default: `http://localhost:3001`.
- Configure `NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_GOOGLE_CLIENT_ID` in
  `.env.local` and Vercel.

Relevant validation commands:

```bash
npm run lint
npm run build
```

### 6.4 Android (`lactic-android`)

- Kotlin 2.4 on AGP 9 (built-in Kotlin), Gradle 9, JDK 21 (Android Studio's
  bundled JBR). compileSdk 37, targetSdk 36, **minSdk 26**.
- Jetpack Compose with Material 3, Material 3 Adaptive, and Navigation 3.
  Studio is tablet-first but must read well on phones.
- Clean architecture: `feature` (stateless `XxxScreen` + stateful `XxxRoute` +
  ViewModel) → `core:domain` (use cases with one `operator fun invoke`,
  repository interfaces) ← `core:data` (implementations over `core:network`,
  `core:database`, `core:datastore`). ViewModels depend only on use cases and
  expose one immutable `UiState` `StateFlow`. `core:model`, `core:common`,
  and `core:domain` are pure Kotlin.
- Hilt (KSP), Retrofit 3 + OkHttp 5 + kotlinx.serialization, Room +
  WorkManager for the workout outbox, DataStore for settings, the refresh
  token encrypted with Tink under an Android Keystore key, Coil 3 for GIF
  exercise animations.
- Cancellation is never an error, so an abandoned load never ends in a
  failure state or restarts itself.
- No analytics or crash SDKs. HTTP logging exists only in debug builds, never
  logs bodies, and redacts `Authorization`.
- Strings in English and Italian, matching the iOS keys and translations.
- DEBUG intent extras mirror the iOS launch arguments (`design_preview`,
  `destination`, `route`, `dev_login`, `invitation`, …) and replay fixtures
  without an account or a server.
- Tests: JUnit 4, Truth, Turbine, MockWebServer, Robolectric + Roborazzi
  screenshot goldens. Spotless (ktlint + Compose rules), detekt (140-column
  lines), and Android Lint, with Kotlin and Lint warnings as errors.
- Nested guidance lives in `docs/android.md`.

Relevant validation commands:

```bash
make lint   # spotlessCheck, detekt, lintDebug
make test   # unit tests and Roborazzi verification
make build  # assembleDebug and assembleRelease (R8)
```

### 6.5 Git and CI

- `main` is the production branch.
- Use short-lived `feature/*`, `fix/*`, or `codex/*` branches.
- Use conventional English commit messages.
- Open a pull request for every feature or fix.
- Do not merge with failed or incomplete checks.
- API GitHub Actions run on pull requests and pushes to `main`:
  - `test`: PostgreSQL-backed Rails test suite.
  - `lint`: RuboCop.
  - `scan_ruby`: Brakeman and bundler-audit.
- The invitation milestone's final backend run passed all three jobs, including
  225 Rails tests.
- Vercel supplies frontend preview/deployment checks. Run lint and a production
  build locally before opening or merging a frontend PR.

---

## 7. Architectural Decision Records

| # | Decision | Rationale |
| --- | --- | --- |
| 1 | Rails API-only backend | Supports iOS and web clients without coupling presentation to Rails |
| 2 | iOS monorepo with two targets | Maximizes shared models, networking, and UI code |
| 3 | Program is a reusable template | One program can be assigned to many clients independently |
| 4 | WorkoutTemplate is separate | Workouts can be saved and reused outside one program/week |
| 5 | Google and Apple only in v1 | Avoids password storage, reset, and verification complexity |
| 6 | Reps-only mode and RIR-only intensity in v1 | Keeps the first release focused and extensible |
| 7 | Global exercise catalog plus coach-owned exercises | Provides immediate utility while allowing customization |
| 8 | One web portal with role guards | Shares infrastructure while preserving distinct coach/client navigation |
| 9 | Server-controlled account roles | Prevents clients from promoting themselves through request parameters |
| 10 | Secure invitation required for unknown clients | Establishes coach ownership and verified identity before onboarding |
| 11 | Resend over HTTPS | Railway hobby deployments may restrict SMTP; HTTPS delivery is reliable |
| 12 | Railway for Rails/PostgreSQL and Vercel for Next.js | Fits each runtime's strengths and preserves simple Git-based deployment |
| 13 | Open coach signup, gated by a paid plan's client limit rather than an allowlist | Removes the manual step from customer acquisition; `COACH_EMAILS` is repurposed as an unlimited comp list instead of deleted, so existing comped access keeps working |
| 14 | RevenueCat Web Billing for subscriptions | Web-only today with a native iOS app as a future target; RevenueCat unifies entitlements across both under one App User ID (the coach's own `User#id`) without committing to Apple In-App Purchase before that app exists |
| 15 | Subscription state always re-derived from `expires_at`, never a stored status | Self-heals if a webhook is missed, delayed, or arrives out of order — RevenueCat's own delivery guarantee is at-least-once with no ordering guarantee |
| 16 | `lactic-ios` generates its Xcode project from `project.yml` (XcodeGen) and git-ignores `Lactic.xcodeproj` | Removes `project.pbxproj` as a merge-conflict surface and makes adding a file a filesystem operation rather than a project edit. Build settings live in `Configs/*.xcconfig` as a direct consequence: the Xcode UI writes into the generated project, where a regenerate silently discards the change |
| 17 | `lactic-android` is one Gradle monorepo with two apps and clean architecture (repository → use case → ViewModel → view) | Mirrors the iOS monorepo's sharing of models, networking, and UI; the iOS code is the behavioural reference, so behaviour and tests are ported rather than re-invented |
| 18 | Google-only sign-in on Android in v1 | Credential Manager covers Google natively; Sign in with Apple on Android needs a web-based flow and no App Review rule requires it there |

---

## 8. Future Scope

- Time-based exercises such as planks and cardio.
- RPE and time under tension.
- Coach/client chat.
- Push notifications.
- Android application.
- Advanced analytics beyond the shipped per-exercise best-weight trend.
- Supersets and linked exercises.
- Photo/video object storage and upload pipeline.
- **Session and per-exercise notes UI in the web portal.** The API has
  supported `workout_sessions.notes` and `exercise_logs.notes` since the
  logging endpoints landed, and §4.1 lists them as a client feature, but
  `lactic-web` never built UI for either. The iOS client writes both, so until
  the web catches up a note taken on the phone is invisible in the browser.
- Apple Sign-In UI in the web portal.
- Sign in with Apple on Android, through Apple's web-based flow.
- Play Store publishing for both Android apps. Play's billing policy raises
  the same question as the App Store IAP item below, so Android Studio's Plan
  stays read-only until it is decided.
- Android App Links for `https://…/invite/*`, so an invitation email opens the
  Android app directly instead of relying on the `lactic://invite` scheme.
- Optional email/password authentication only if product requirements change.
- In-App Purchase for the native iOS Lactic Studio app once it exists.
  RevenueCat already unifies entitlements across web and app-store purchases
  under one App User ID, but Apple guideline 3.1.3(b) only permits honoring a
  web purchase inside an app if the same subscription is *also* sold via IAP
  in that app — a login-only iOS client selling nothing itself is not a safe
  assumption (a near-identical B2B coaching app was rejected under 3.1.1
  citing this exact confusion). Decide the IAP question before that app ships,
  not after.

---

## 9. Agent Instructions

### 9.1 General

- Write code, comments, commits, and technical documentation in English.
- Follow the conventions for the repository being changed.
- If work spans Rails, web, or iOS, implement and verify every affected side.
- When modifying the data model or a major flow, update this file and copy the
  same result to every Lactic repository.
- Keep each root `CLAUDE.md` as a relative symlink to `AGENTS.md`.
- Never commit secrets. Use environment-variable names and placeholders only.
- Preserve the invitation security invariants: hashed token, expiry,
  revocation, single use, social-email match, coach ownership, and
  server-controlled role assignment.
- Preserve the Sign in with Apple invariants: the verifier's audience list is
  never empty, a relay address never satisfies an invitation's email match,
  and deleting an account revokes its stored Apple token first.
- Preserve the billing invariants: the RevenueCat webhook is
  signature-verified and idempotent per `event_id`; stored subscription
  state is always re-fetched from RevenueCat rather than trusted from a
  webhook payload; access is derived from `expires_at`, never a stored
  status, so it self-heals if a webhook is ever missed.
- Prefer the simplest v1 implementation and briefly note meaningful
  alternatives.
- Ask before proceeding only when an ambiguity materially changes the product,
  data model, security model, or external side effects.
- Produce complete working files rather than partial snippets.

### 9.2 Deployment work

- Use the explicit production project/environment/service IDs in section 2.4;
  do not rely on whichever project happens to be linked locally.
- A queued or building deployment is not a success. Wait for Railway `SUCCESS`
  or Vercel `READY` before reporting completion.
- After backend deployment, verify `/up` returns HTTP 200.
- After frontend deployment, verify the production alias points to the expected
  commit and returns HTTP 200 on a real route.
- Never print or retrieve secret values unless the user explicitly needs a
  narrowly scoped secret operation.

### 9.3 Developer context

The lead and sole developer is an experienced iOS developer with limited Rails
experience. Be concise on iOS topics and slightly more explanatory for Rails,
PostgreSQL, web deployment, and backend security decisions.
