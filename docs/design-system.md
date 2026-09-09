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
