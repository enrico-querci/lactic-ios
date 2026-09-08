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
| **Lactic** | Client | iOS | Follow assigned programs and log workouts | In development in `lactic-ios`; see `docs/ios-plan.md` |
| **Lactic Studio** | Coach/Admin | Web today; iOS/iPadOS planned | Manage clients and create training programs | Coach routes (`/coach/**`) in Lactic Web are implemented and deployed; a native app is a product target |
| **Lactic Web** | Coach and client | Web | Browser access to both role-specific experiences | Implemented and deployed |
| **Lactic API** | All clients | Rails API | Shared auth, business logic, persistence, email, and REST API | Implemented and deployed |

**Lactic Studio** names the coach/admin dashboard as a product, independent of which
surface currently implements it — today that is the coach routes inside Lactic Web;
a native iOS/iPadOS app remains a future target, not a separate product to track
alongside it. Coaches are the paying customer, so Lactic Studio is expected to be the
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

---

## 2. Architecture

### 2.1 Repositories

| Repository | Contents |
| --- | --- |
| `lactic-ios` | iOS monorepo: Lactic (iPhone client), Lactic Studio (iPad coach), and the shared `LacticCore`/`LacticKit`/`LacticUI` packages |
| `lactic-api` | Ruby on Rails API-only backend |
| `lactic-web` | Next.js web portal with coach and client routes |

### 2.2 Technology stack

| Layer | Technology |
| --- | --- |
| iOS | Swift 6.x, SwiftUI, modular Swift Packages |
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
- The web UI currently implements Google Sign-In. The API also supports Apple.
- The API issues short-lived JWT access tokens and refresh tokens.
- A user has exactly one role: `coach` or `client`.
- Existing users sign in normally using their linked provider identity.
- An unknown client must present a valid invitation token during social sign-in.
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

#### ExerciseLog

- `id`, `workout_session_id`, `workout_exercise_id`.
- Client notes and optional execution photo URL.

#### SetLog

- `id`, `exercise_log_id`, `position`, `weight_kg`, and performed `reps`.

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

### 6.4 Git and CI

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

---

## 8. Future Scope

- Time-based exercises such as planks and cardio.
- RPE and time under tension.
- Coach/client chat.
- Push notifications.
- Android application.
- Advanced analytics and progress charts.
- Supersets and linked exercises.
- Photo/video object storage and upload pipeline.
- Apple Sign-In UI in the web portal.
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
