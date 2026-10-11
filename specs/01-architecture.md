# Architecture

## Project

XcodeGen `project.yml`, one app target `VisionSpacecraft` (visionOS 26), bundle
`org.dicyaninlabs.visionspacecraft`. Local SwiftPM packages under `Packages/`:

| Package | Depends on | Contents |
|---|---|---|
| `SpacecraftCore` | none | Part model, craft graph, mass properties, units. Pure Swift, macOS-testable |
| `FlightSim` | SpacecraftCore | Fixed-step 6-DOF integrator, atmosphere, aero, propulsion, heat, failure checks |
| `FlightCode` | SpacecraftCore | Lexers and parsers for Python and C subsets, shared IR, bytecode VM, craft API |
| `Curriculum` | FlightCode | Lesson definitions, graders, mini game logic |
| `SpacecraftRender` | RealityHD, FlightSim | Maps parts to RealityHD entities, exhaust, heat glow, trajectory ribbons |
| `DicyaninStageDirector` | external | Route control for screenshots and demo capture |

`FlightSim` and `FlightCode` never import RealityKit. The simulator runs headless in tests and on a
background actor in the app.

## Scenes

| SwiftUI scene | Type | Purpose |
|---|---|---|
| `main` | WindowGroup | Home: missions, lessons, saved crafts |
| `code` | WindowGroup | Code editor, block mode and text mode |
| `analysis` | WindowGroup | Plots, run list, failure report |
| `workshop` | ImmersiveSpace, mixed then full | Life-size hangar |
| `range` | ImmersiveSpace, full | Launch range and courses |
| `concept` | Volume | Lesson mini game diorama |

Only one ImmersiveSpace is open at a time. Code and analysis windows stay open across both.

## Runtime loop

1. Player edits code. `FlightCode` compiles on each pause in typing (300 ms debounce).
2. On success the preview runner simulates the full flight headless at 10x real time with the current
   craft and course, and returns the trajectory polyline plus the failure event, if any.
3. `SpacecraftRender` draws the preview ribbon in the range or as a tabletop overlay.
4. On Launch, the live runner steps `FlightSim` at 240 Hz; the VM `update(dt)` runs at 50 Hz (the
   guidance rate). Render reads the latest state snapshot at display rate and interpolates.
5. Every run writes a `FlightRecord` (`11-data-model.md`) for analysis and replay.

Preview and live runs use the same code, seed and integrator, so a preview is an exact forecast unless
the course has randomized wind, which is shown as a band of 8 sampled ribbons.

## Concurrency

`FlightSession` is an actor owning sim state and VM. Render consumes `AsyncStream<FlightSnapshot>`.
The VM has an instruction budget per guidance tick (100k instructions); exceeding it counts as a
missed tick, logged as a runtime fault.

## Quality presets

RealityHD `.balanced` default, `.high` in the workshop where the player stands close to parts.
Target 90 fps; frame budget table in `12-test-plan.md`.
