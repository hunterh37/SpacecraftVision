# Vision Spacecraft PRD

Bundle ID `org.dicyaninlabs.visionspacecraft`. Platform visionOS 26, Xcode 26, Swift 6.2, RealityKit.
Status: specification only. No code exists.

## Summary

Vision Spacecraft is a life-size Apple Vision Pro game in the style of Kerbal Space Program, built to
teach programming through flight. The player builds a rocket or aircraft at 1:1 scale in a hangar,
writes the guidance code that flies it, launches it, and reads the result. The teaching topic is
obstacle avoidance: the craft only survives a course when the player's code steers it through.

All 3D content is generated at load time by RealityHD (`~/Dev/RealityHD`, SwiftPM product
`RealityHD`). The app ships no mesh or texture files. Missing parts are added to RealityHD as new
briefs and props (see `specs/04-realityhd-assets.md`).

## Players

| Player | Need |
|---|---|
| High school and early university students | First contact with control loops, sensors and algorithms |
| Hobbyist programmers | See how a code change alters a physical trajectory |
| Educators | A lesson sequence with measurable outcomes per student |

## Goals

1. Teach obstacle avoidance algorithms from concept to running code.
2. Let the player change code, run it, and preview the new flight path before and during flight.
3. Let the player build and customize rockets and aircraft from a limited part list.
4. Model mass, thrust, drag, energy and heat with published physical values, so a design that fails in
   the game fails for a reason that holds in reality.
5. Render photoreal parts, lighting and sound at life-size scale.

## Non-goals (v1)

Orbital mechanics beyond suborbital arcs, multiplayer, user-uploaded meshes, real CFD, full MATLAB
compatibility, App Store in-app purchases.

## Learning process

Every lesson runs the same five stages. `specs/06-curriculum.md` defines each lesson.

| Stage | Player activity | Surface |
|---|---|---|
| 1 Concept | Watch a spatial explanation, play a mini game that acts out the algorithm by hand | Immersive diorama |
| 2 Pseudocode | Arrange pseudocode blocks into the algorithm's structure | Code window, block mode |
| 3 Implement | Write the same algorithm in Python or C | Code window, text mode |
| 4 Run | Fly the craft with the code in the life-size range | Immersive space |
| 5 Test and analyze | Read plots, telemetry and failure reports; compare runs | Analysis window |

## Scenes and modes

| Mode | Content | Spec |
|---|---|---|
| Workshop | Hangar at 1:1 scale. Build, customize, inspect mass, center of mass, thrust, cost | `specs/02-workshop.md` |
| Design goals | Mission brief picker: payload, range, altitude, course. Sets the constraints the build must meet | `specs/02-workshop.md` |
| Coding | Lesson code editor beside the craft, sensor and actuator API reference, preview path | `specs/05-coding-runtime.md` |
| Flight test | Launch on the range, obstacle course, follow cam, tabletop overview, replay | `specs/03-flight-test.md` |
| Analysis | Plots in MATLAB style, run comparison, failure cause | `specs/08-analysis.md` |

## Languages

Python (subset) and C (subset) in v1, both compiled to one sandboxed bytecode VM in Swift. Ada and a
MATLAB-like script language are v2 candidates. MATLAB itself is used only as the reference style for
plots and as an optional export target (`.m` and `.csv`). Rationale in `specs/05-coding-runtime.md`.

## Failure rules

A craft fails on: energy depletion, mass over limit, thrust to weight below 1 at launch, structural
overload, overheating, collision, or leaving the course corridor. Parts come from a limited list per
mission. Full rules and values in `specs/07-failure-rules.md`.

## OpenVSP

OpenVSP (NASA, open source) is the reference for aircraft geometry parameters (wing span, sweep,
taper, airfoil) and drag estimates. v1 copies its parameter names and precomputes coefficient tables
offline. v1.1 imports `.vsp3` wing parameters. The app does not run OpenVSP on device.

## Success metrics

| Metric | Target |
|---|---|
| Lesson 1 completion, first session | 70% |
| Median edit-to-flight loop | under 20 s |
| Frame rate in flight with full course | 90 fps |
| Physics regression suite | 100% pass against reference trajectories |
| Pre/post quiz gain per lesson | +30 points |

## Milestones

M0 docs (this), M1 workshop and parts, M2 flight physics, M3 code VM, M4 lessons 1 to 3, M5 analysis
and polish, M6 TestFlight. Detail in `specs/10-milestones.md`.

## Spec index

`specs/00-index.md`.
