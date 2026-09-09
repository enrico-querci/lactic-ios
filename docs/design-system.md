# Lactic visual direction

Lactic uses chalk, graphite, and electric lime: a focused training interface
with a recognizable accent. Shared tokens live in `Packages/LacticUI` and serve
both the client app and Studio. No font files or styling dependencies are needed.

| Role | Light | Dark |
| --- | --- | --- |
| Page | Chalk `#F5F6F0` | Graphite `#10130F` |
| Card | White `#FFFFFF` | Lifted graphite `#22271F` |
| Primary text | `#192118` | `#F4F6EE` |
| Secondary text | `#505B49` | `#B5BEAB` |
| Muted text | `#697360` | `#99A38F` |
| Interactive accent | Deep green `#466B12` | Lime `#CCF36B` |

Hero panels stay `#192118` in both appearances, with `#F4F6EE` text and lime
highlights. Never place small lime text on a white surface. Use the adaptive
accent for links, selected tabs, and primary buttons. Status colors retain
their semantic meaning; lime is the brand, not an error or warning indicator.

Typography uses native SF text styles with Dynamic Type. Heavy large titles
mark brand moments, bold titles lead cards, semibold headlines organize
sections, and regular body text carries instructions. Caption-sized bold
eyebrows label sections sparingly. Timers and workout values use monospaced
digits. Avoid fixed font sizes and truncation of exercise names or instructions.

Spacing follows a 4/8/12/16/24/32 pt scale. Cards use 20 pt continuous corners,
controls 14 pt, and badges capsules. Keep at least 44 pt interactive targets.
Navigation remains native; the interface follows the device appearance.

The sign-in, current-programme card, shared controls, and Studio scaffold show
the direction. The debug component gallery documents typography and palette.
Existing contrast tests protect text on page/card surfaces, button labels,
status badges, and disabled-state hierarchy.

## Home dashboard

Home is a training launchpad, not a duplicate programme browser. The first
graphite panel is always the most useful action: resume an unfinished workout,
or start the next workout in programme order. It includes enough prescription
detail to make the decision without opening another screen.

The current programme follows with progress and the coach's guidance. Recent
activity is deliberately compact and only includes completed sessions; an
unfinished session belongs in the hero. Every card is a direct navigation
target, and pull to refresh reloads the complete dashboard.

The empty state uses the same graphite brand moment without implying an error.
The debug gallery includes a Home preview backed by synthetic data. Launch with
`--home-design-preview` for the next-workout state, or add `--home-resume` for
the in-progress state. Neither route exists in Release.

## Workout execution

The workout overview uses a graphite panel for the session name and counts.
Exercise cards lead with a lime position marker, a bold name, and logged-set
progress. Prescribed targets, coach notes, and previous performance remain
separate from the client's recorded values.

Each recorded row carries a checkmark, large monospaced weight/repetition
inputs, and a menu for deletion. The checkmark means the set was logged;
the existing session sync indicator still reports pending or failed writes.
The keyboard's Done action commits an edit by ending focus.

"Log set" records a performed set using the existing coach-value defaults
and starts rest. It becomes "Log extra set" once the prescribed count is
reached. Counts continue beyond the target while the progress bar caps at
100%. Logging remains backed by the existing recorder and outbox.

Rest occupies its own full-width panel. Idle and running states retain the
same layout; running uses graphite and lime. At accessibility text sizes,
set controls and timer content stack vertically. No fixed font sizes or
newer-than-iOS-18 APIs are required.

The debug gallery includes a Workout preview backed by synthetic data and a
network-blocking transport. Launch with `--workout-design-preview` to open it
without authentication; add `--workout-design-timer` for the active timer.
Preview writes are never persisted, and both routes are excluded from Release.

## Programme browsing and detail

The programme list opens with a compact graphite summary, then gives each
active assignment a full card. Programme status, start date, description, and
coach guidance are visible before navigation; the entire card remains the
single interaction target.

Programme detail combines the plan structure with real session history. Its
hero reports week and workout counts plus distinct completed-workout progress.
Each week repeats that progress locally, and every workout is marked upcoming,
in progress, or completed. An unfinished session wins over earlier completed
sessions for the same workout so the next useful action is never obscured.

Workout rows use a lime weekday tile, clear prescription counts, and wrapping
muscle-volume chips. They navigate into the existing execution flow without
adding a second start or resume model. Pull to refresh reloads the programme and
session history together.

The debug gallery includes list and detail fixtures. Launch with
`--programme-design-preview --programme-list` for browsing, or omit
`--programme-list` for detail. Both routes use synthetic data and are excluded
from Release.

## History and progress

History opens with lifetime training metrics, then separates unfinished work
from completed sessions. A session is a full-card navigation target with its
workout name, date, duration, and note; no database identifiers are exposed as
display labels. The API includes this context directly, while the client keeps
a best-effort workout fetch for compatibility during a rolling deployment.

Session summaries treat the performed work as the source of truth. The hero
shows sets, repetitions, volume, and duration; exercise cards preserve workout
order, surface both session and exercise notes, and link to the exercise's own
progress when an exercise identifier is available. Set values use monospaced
digits and stack at accessibility sizes.

Exercise progress combines the catalog reference with the client's training
record. Its chart plots the heaviest set per completed session rather than each
individual set, keeping the trend readable. Summary metrics, change since the
first recorded session, personal-best treatment, and grouped recent sets use
the same data returned by exercise history. Older servers that omit session
context still render a flat recent-set list.

The debug gallery includes all three states. Launch with
`--history-design-preview` for History, then add `--history-session` or
`--history-exercise` for the corresponding detail. All use synthetic data and
are excluded from Release.
