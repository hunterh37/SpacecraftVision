# Task Guidance V0 — Implementation Notes

Standalone BUILD-phase task guidance prototype. Not integrated into the Vision Pro application.

## Package

`Packages/TaskGuideKit/`

| Module | Role |
|---|---|
| `TaskGuideCore` | Task definitions, craft/preflight snapshots, deterministic evaluation, in-memory engine |
| `TaskGuideUI` | Task board, 2D guidance highlight, isolated demo preview |

## Mission

**Build Your First Rocket** — four BUILD steps only.

1. `missionBrief` — manual acknowledgment (“I understand”)
2. `partsPalette` — manual acknowledgment (“I've found the parts”)
3. `craftAssembly` — automatic validation of `probe-core`, `fuel-tank-s`, `engine-liquid-small`
4. `statBoard` — automatic validation: essential parts, no launch blockers, TWR SL > 1.0

LAUNCH and SPACE appear in the roadmap as **Coming later** and are not implemented.

## Preview

Open `TaskGuideDemoView` via the `#Preview("Task Guide Demo")` in:

`Packages/TaskGuideKit/Sources/TaskGuideUI/TaskGuideDemoView.swift`

Or from a host that imports `TaskGuideUI` (this package is not wired into the Xcode app target).

Demo fixture picker: Empty / Partial / Fully assembled / Assembled but blocked / Launch-ready.

Expected path with Launch-ready fixture:

Start Build → Task 1 acknowledge → Task 2 acknowledge → Task 3 already satisfied → Task 4 already satisfied → “Build phase complete. Ready for the Launch phase.”

## Tests

```bash
cd Packages/TaskGuideKit
swift test
```

## Boundaries

- Does not modify `HomeView`, `AppModel`, Walkthrough, immersive scenes, or `project.yml`.
- Does not depend on SpacecraftKit, RealityKit, or network/AI services.
- Reset Guide clears only guide session state; the input snapshot is unchanged.
- Guidance target IDs are semantic (`missionBrief`, `partsPalette`, `craftAssembly`, `statBoard`) for future RealityKit reuse.

## Integration requirements (future, not in V0)

1. Add `TaskGuideKit` as a local package dependency in the app Xcode project / `project.yml` (requires explicit approval).
2. Map AppModel craft + blockers + TWR into `CraftStateSnapshot`.
3. Bind semantic target IDs to real Workshop UI / RealityKit anchors (do not copy `SpatialIndicators.swift`).
4. Present `TaskBoardView` from an approved entry point without replacing Walkthrough tours.
