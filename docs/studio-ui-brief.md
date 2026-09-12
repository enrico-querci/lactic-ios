# Lactic Studio — UI implementation brief

> Handoff for the agent building Lactic Studio's interface.
> Written 2026-09-12, against `main` at `be11981`.

Build the Lactic Studio UI — the iPad-first coach app — in the `lactic-ios`
repo, target `LacticStudio`, bundle id `com.enricoquerci.lacticstudio`.

---

## 1. Division of labour

You own the UI. The business logic is already written and lives in
`Packages/LacticKit`. Do not reimplement it in views, and do not put
networking, derivation or state logic into the app target.

This boundary is deliberate and was recently repaired: the client app's
derived metrics had accumulated inside `Apps/Lactic/Features/**/*Model.swift`,
which meant neither side could work without touching the other's files. Five
value types moved into `LacticKit/Progress/` to fix it. Please do not
re-create that problem on the coach side.

If something you need is missing from LacticKit, say so rather than working
around it in a view.

## 2. Scope for v1

Deliberately narrow.

1. **Sign-in** — restyle `Apps/LacticStudio/StudioSignInView.swift`.
   It works today; it is simply unstyled.
2. **Client list** — an iPad `NavigationSplitView` showing the coach's
   clients and their pending invitations, with invite, resend and revoke.

**Out of scope**, explicitly: the program builder, exercise picker, workout
templates, program assignments, and any billing or paywall UI.

## 3. What already exists

### `ClientListModel` — bind to this

`Packages/LacticKit/Sources/LacticKit/Coach/ClientListModel.swift`.
`@MainActor @Observable`. Construct with the environment's `client`.

| Member | |
| --- | --- |
| `load()` | Fetches clients, invitations and subscription concurrently |
| `invite(email:)` | Returns `false` on refusal; see `failure` |
| `resend(invitationID:)` | Rotates the token and expiry, re-sends the email |
| `revoke(invitationID:)` | Also refreshes the plan — a freed slot shows immediately |
| `removeClient(id:)` | Unlinks; the client's logged history is not deleted |
| `clients`, `pendingInvitations`, `subscription` | |
| `isLoading`, `isSubmitting` | Separate, so the list stays on screen during an action |
| `failure`, `canInviteClient` | |

### Everything else

- **`CoachAPI`** — the whole `/api/v1/coach/**` surface, if you need more reads.
- **`StudioEnvironment`** — `client`, `session`, `locale`, and a DEBUG server
  picker. Injected via `@Environment(StudioEnvironment.self)`.
- **`Apps/LacticStudio/Resources/Localizable.xcstrings`** — English and
  Italian. Every new user-facing string goes in it, with an Italian
  translation. `#if DEBUG` strings are deliberately excluded; keep it that way.
- **`LacticUI`** — the shared design system. `docs/design-system.md` is the
  direction: chalk, graphite, electric lime.

## 4. The one state that needs real design

`ClientListModel.failure` is a `CoachActionFailure`, and its cases are not
interchangeable:

- **`.planIsFull`** — HTTP 402. The coach's plan is full. This is *not* a
  generic error: the way out is upgrading, not correcting the input, so it
  deserves its own treatment and should show
  `subscription.clientSlotsUsed` against `clientLimit`. A `nil` limit means
  unlimited.
- **`.rejected(String)`** — the server's own per-case wording, written for a
  human ("This person already belongs to another coach"). Show it as-is.
- **`.offline`** — connectivity, not a refusal the coach can fix by editing.

Note that `canInviteClient` stays permissive while the subscription is
unknown. Offer the invite control and let a 402 explain, rather than hiding it
silently — a coach who cannot invite and is not told why is the worse outcome.

## 5. Conventions

- `project.yml` is the source of truth; `Lactic.xcodeproj` is generated and
  git-ignored. Run `make project` after adding files. Build settings belong in
  `Configs/*.xcconfig` — the Xcode UI writes into the generated project, where
  a regenerate discards the change.
- Swift 6 language mode, SwiftUI, `@Observable`. Minimum target iOS 18.0,
  built against the iOS 26 SDK, so any iOS 19+ API stays behind `@available`.
- Tests use Swift Testing (`@Test` / `#expect`), not XCTest. The one exception
  is `LacticFlowTests`, which needs `XCUIApplication`.
- Follow the `--*-design-preview` launch-argument pattern from the client app,
  so screens can be reviewed without authentication or live API data.
- `make lint`, `make test` and `make build` must all be clean, and the Release
  configuration must build — it is warnings-as-errors.
- Check the result on an iPad simulator in light and dark appearances, and at
  accessibility Dynamic Type sizes.

## 6. Do not

- **Ship a paywall, or anything that sells a subscription.** Apple guideline
  3.1.3(b) is unresolved for this app — see `AGENTS.md` §8. This is the single
  thing that could make Studio unshippable, so leave it alone entirely.
- Add derivation or fetching logic to `Apps/LacticStudio/**`.
- Touch the client app's screens.

## 7. Known gap

There is **no model for a client detail screen** — progress, past sessions.
Only `CoachAPI.clientProgress(clientID:)` and `clientSession(clientID:sessionID:)`
exist at the transport level. If the design calls for that screen, flag it;
the model will be written on the LacticKit side rather than in the app target.
