# Walkthrough plan

## Over-budget report

Reference craft R-hop costs 18,700 cr against the M1/M1W budget of 20,000 cr (11 parts, cap 12).
Launching with the default craft passes every check. The blocker appears after parts are added in
the hangar: one extra engine (+6,500 cr), IMU (+2,500 cr) or probe core (+4,000 cr) exceeds the budget.
Before this change the range showed "Cannot launch. Over budget" with no fix path, and the error
stayed on screen after the craft changed.

Changes:
- `AppModel.addBlock(_:)` returns the cap a part would break; `addPart` refuses it.
- Parts window greys out those parts with the reason ("+6500 cr. Over budget by 5200 cr") and shows a budget meter.
- Range HUD shows a five-check preflight (command, mass, parts, budget, code) while idle. A failed
  check names the blocker and offers Load reference craft and Open hangar. Launch is disabled until all pass.
- Stat board offers Load reference craft under any blocker.
- `launchError` clears on every craft or code change while idle.

## Game loop

Home (Learn / Missions / Workshop) -> mission brief -> hangar build (Parts window + stat board)
-> code (editor, live predicted path) -> range preflight -> launch -> watch (Ground / Chase / Tabletop,
0.25x to 4x) -> result card -> Analysis plots -> change code or craft -> relaunch. Lessons wrap the
same loop with concept, pseudocode and graded analysis stages.

## Mode tours (v2)

One tour per mode, started the first time each mode screen opens; the range tour starts the first
time the range opens. Tours queue when another is active. Done set: `walkthrough.v2.done`.
Settings toggle `walkthrough.enabled` (default on) disables auto-start and window tips.
Card (main window trailing ornament; range callout): Next (manual steps), Show me (performs the real
action via the step's `demo`, then advances), Play rest (autoplays remaining steps and queued tours),
Take over (stops autoplay), Skip tour.

| Tour | Steps |
|---|---|
| Learn | pick lesson 00, concept, pseudocode (demo fills correct order), implement (opens editor, loads reference code), run (range, 4x), analyze (answers correctly) |
| Missions | mission list, select, code first, fly (hands off to range tour) |
| Workshop | enter hangar, add a part, arrange, tabletop, reference craft, to the range |
| Range | pad, predicted path, preflight, launch, views, debrief |

Settings (Home bottom ornament): guided walkthroughs toggle, replay per tour, reset all, Watch full demo
(Learn -> Missions -> Range -> Workshop, autoplayed). Mode screens have a Tour button.

## First-run steps (range)

Starts the first time the range opens. Persisted in `walkthrough.v1.done`.

| # | Step | Trigger | Indicator | Completion |
|---|---|---|---|---|
| 0 | The pad | Range opens | Pad ground ring + 40 m light column, leader dots | Next |
| 1 | Predicted path | After 0 | Halo at the predicted apogee, leader dots | Next |
| 2 | Preflight | After 1 | Callout beside HUD | All blockers clear and code compiles |
| 3 | Launch | After 2 | Halo at craft base, pad column, leader dots | `flight.phase != .idle` |
| 4 | Views | After 3 | Callout | View changed or flight finished |
| 5 | Debrief | After 4 | Callout | Analysis window appears |

Each callout: small-caps title, one line, Learn more (one detail paragraph), step dots, Skip tour
(turns accent after 20 s). Completed steps play a white ring burst at the callout.

## Contextual tips (once each, `walkthrough.v1.tips`)

| Tip | Where | Trigger |
|---|---|---|
| Launch blocked | Range callout | Any blocker while idle; auto-dismisses when cleared |
| Failed flight | Range callout | First failed flight |
| Hangar | Parts window banner | First open |
| Flight code | Code editor banner | First open |

## Entry points

- Auto on first range open.
- Home bottom ornament: Settings. Mode screen bottom ornament: Tour.
- Launch args: `-walkthroughReset`, `-walkthroughStep N`.

## Files

- `VisionSpacecraft/Walkthrough/WalkthroughModel.swift`: steps, predicates, tips, persistence.
- `VisionSpacecraft/Walkthrough/CalloutView.swift`: `TourCard`, range callout, window `TipBanner`.
- `VisionSpacecraft/Views/SettingsView.swift`: toggle, replay, full demo.
- `VisionSpacecraft/Walkthrough/Indicators/SpatialIndicators.swift`: ground ring, light column, halo, leader dots, burst.

## Open items

- No DicyaninStageDirector routes in this project yet, so step stills are not captured.
