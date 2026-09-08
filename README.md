# Lactic iOS

iOS monorepo for the Lactic ecosystem: two app targets sharing three local
Swift packages.

| Target | Audience | Device | Bundle id |
| --- | --- | --- | --- |
| **Lactic** | Client | iPhone | `com.enricoquerci.lactic` |
| **Lactic Studio** | Coach | iPad first | `com.enricoquerci.lacticstudio` |

Read [`AGENTS.md`](AGENTS.md) for the product, data model and cross-repository
conventions — it is byte-identical across `lactic-api`, `lactic-web` and this
repo. The implementation plan lives in [`docs/ios-plan.md`](docs/ios-plan.md).

## Setup

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen),
SwiftLint and SwiftFormat:

```bash
brew install xcodegen swiftlint swiftformat
make project      # generates Lactic.xcodeproj
open Lactic.xcodeproj
```

`Lactic.xcodeproj` is **generated and git-ignored**. `project.yml` is the source
of truth for targets, schemes and dependencies; `Configs/*.xcconfig` is the
source of truth for build settings. Editing a build setting through Xcode's UI
works until the next `make project`, which discards it — change the xcconfig
instead.

## Tasks

```bash
make            # list every task
make build      # both app schemes, iOS Simulator
make test       # package tests on the host, then both app schemes
make lint       # swiftformat --lint and swiftlint
make format     # apply formatting
```

`make test-packages` runs only the Swift Package tests. They execute on the host
without a simulator, so they are the fast inner loop for anything in
`LacticCore` or `LacticKit`.

Override the simulator if you do not have the default one, or replace the
destination entirely:

```bash
make test SIMULATOR="iPhone 17" IOS=26.5
make build DESTINATION="generic/platform=iOS Simulator"
```

CI runs `lint`, the package tests, and a generic-destination build of both app
targets. It deliberately does **not** run the app-scheme tests: those need a
booted simulator, which is slow and ties CI to whichever iOS runtimes the
runner image ships. Run `make test` locally before pushing.

## Packages

| Package | Contents |
| --- | --- |
| `LacticCore` | Utilities, extensions, constants, coding helpers. No dependencies. |
| `LacticKit` | Models, networking, API client, auth, session persistence. |
| `LacticUI` | Design system and shared UI components. |

Most code belongs in a package rather than an app target: packages build and
test on the host without a simulator, and both apps can use them.

## Running against a local API

The apps talk to [`lactic-api`](https://github.com/enrico-querci/lactic-api).
Point them at a local server rather than production while developing:

```bash
cd ../lactic-api
bin/rails dev:seed      # coach, client, program, assignment, one logged session
bin/rails server        # http://localhost:3000
```

`dev:seed` matters: a fresh database has no program assignments and no workout
sessions, so without it every client screen is legitimately empty and a bug is
indistinguishable from no data.

Sign in during development with the API's dev-only route, which does not exist
in production:

```
POST /api/v1/auth/dev_login  {"email": "alice@example.com"}
```

`Info.plist` sets `NSAllowsLocalNetworking`, which is what permits plain HTTP to
`localhost`. It relaxes App Transport Security for local and private-range hosts
only, never for the public internet.

## Conventions

- Swift 6 language mode, complete concurrency checking, iOS 18.0 minimum.
- Built against the iOS 26 SDK, so both apps adopt Liquid Glass on iOS 26+
  devices while still running on iOS 18. Every iOS 19+ API stays behind an
  `@available` check.
- Tests use [Swift Testing](https://developer.apple.com/documentation/testing)
  (`@Test` / `#expect`), not XCTest.
- Never commit secrets. Document environment variable names only.
