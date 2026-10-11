# Assembly bay

Refines the Parts view in the hangar (`02-workshop.md`). The player builds the rocket from full-size
3D parts in the hangar, either by watching an automatic build or by grabbing and joining parts by hand.
Both modes run on one build plan, so the step list, tips and checks are the same in each.

## Loop

1. Open Workshop. The craft spot is an empty pad ring at [0, 0, -3]. Parts for the mission sit on
   racks around the pad, life size.
2. A tip card offers two buttons: Watch build and Build it myself. A third, Skip, loads the
   finished reference craft (the current behavior).
3. Each build step shows a ghost of the next part at its target, a pulsing node ring, and a tip.
4. Finished craft drops into the existing stat board, code and range loop unchanged.

## Build plan

`AssemblyPlan` in `SpacecraftCore`, pure data, unit tested.

| Field | Meaning |
|---|---|
| `steps: [AssemblyStep]` | Ordered, derived from a `CraftDesign` (default: mission reference craft) |
| `AssemblyStep.partId` | Catalog id |
| `AssemblyStep.parent` | Stack index or radial parent; `nil` for the root (command part on top is placed last on a rocket, so the stack is built bottom up: engine, tank, decoupler, tank, avionics, chute, nose) |
| `AssemblyStep.node` | `.stackTop`, `.radial(angle)` |
| `AssemblyStep.symmetry` | 1, 2, 3, 4 (fins placed as one step with mirrored copies) |
| `AssemblyStep.tipId` | Key into `16-ui-copy.md` tip strings |
| `AssemblyStep.concept` | Short physics reason, e.g. "Fins below the center of mass keep the nose forward" |

Order rule: stack bottom to top, then radial parts by parent from the bottom up. The target pose of
each step comes from `CraftBuilder` span math, so the plan and the rendered craft cannot disagree.
`CraftBuilder` gains `targetTransform(for step:) -> Transform`.

Free build (no plan) keeps today's Part picker behavior with snapping added; tips then react to stat
board failures instead of plan steps.

## 3D parts in the scene

- Racks: two RealityHD `part-rack` props left and right of the pad, 3 m apart. Each mission's
  allowed parts appear on them at 1:1, one per slot, with a floating label (name, mass, cost).
- Large parts (tanks over 2 m) lie on a cradle on the floor beside the rack.
- A part already used still shows on the rack as a dimmed copy with its count.
- Parts are `ModelEntity` with `InputTargetComponent`, `CollisionComponent` (box from the catalog
  diameter and length) and `HoverEffectComponent`.

## Watch build (autoplay)

- Timeline per step: part lifts off the rack (0.6 s), flies on an arc to 0.5 m above its node
  (1.2 s), rotates to its target pose, lowers and locks (0.5 s), lock flash, clank sound, stat
  board ticks.
- Transport ornament: Play/Pause, Step back, Step forward, Speed 0.5x/1x/2x, Take over.
- Take over stops at the current step and switches to manual with the same plan position.
- The tip card narrates each step while it plays; the camera never moves (the player walks freely).

## Build it myself (manual)

| Gesture | Effect |
|---|---|
| Look + pinch-hold a rack part | Picks it up. Large parts follow the hand with a 0.15 s lag to read as heavy |
| Move | Part follows the hand; nearest valid node within 40 cm shows its ring |
| Within 15 cm of the correct node | Part eases to the ghost pose (magnetic pull), ring turns telemetry cyan |
| Release while snapped | Lock: 0.3 s slide-in, flash, clank, haptic-style sound, step advances |
| Release elsewhere | Part floats back to its rack slot |
| Two-hand twist | Rotates radial parts in 15 degree steps (symmetry copies follow) |
| Pull a locked part 40 cm away | Detaches it and every child; plan steps rewind |

Wrong part at a node: the ring turns ignition orange, the part refuses to lock, and the tip names
the expected part ("Tank goes here. The engine sits on the bottom."). In free build any valid node
accepts any part that passes `addBlock` checks.

Two-hand assist: a part longer than 2 m can be held with both hands; the midpoint drives position
and the hand axis drives orientation.

The 1:20 tabletop toggle stays. In tabletop the same gestures run on the bench model with snap
radii scaled by 0.05.

## Tips and visuals

All 3D guidance uses the walkthrough vocabulary (`notes/walkthrough/PLAN.md`) and `Brand` tokens.

| Element | Look |
|---|---|
| Ghost target | Part mesh, unlit `telemetry` at 25% alpha, slow 1.5 s breath |
| Node ring | Torus at the node, `telemetry`; `ignition` on a wrong part |
| Grab hint | Ring plus pinch glyph above the next part on the rack |
| Path hint | Dotted `trajectory` arc from rack part to ghost, only in the first two steps |
| Tip card | RealityView attachment, `labPanel` style, 0.6 m wide, anchored 0.4 m beside the ghost, billboarded to the head |
| Lock | Cyan ring flash expanding to 1.5x, 0.25 s |
| Done | Pad ring fills, stat board pulses, card shows "Craft ready. Write the flight code." |

Tip card content per step: step n of N, part name, one-line action, one-line concept. Card buttons:
Show me (plays this step only, then returns control), Next (manual mode, enabled after lock), Hide.

Reduce Motion: autoplay jumps straight to each locked pose with a fade; no arc or breathing.

## Model and state

- `AssemblyModel` (`@Observable`, app target): `plan`, `index`, `mode` (`.watch`, `.manual`, `.free`),
  `held: UUID?`, `speed`. Each lock calls the existing `AppModel.addPart` / radial add, so the
  `CraftDesign` and stat board stay the single path for craft changes.
- Rewind removes parts through the existing remove path.
- Progress persists per mission in `assembly.<missionId>.index` so an exit mid-build resumes.

## Walkthrough

The Workshop tour (`enter hangar, add a part, arrange, tabletop, reference craft, to the range`)
becomes: enter hangar, Watch build (first three steps), Take over, lock one part by hand, tabletop,
to the range. Its Show me uses the plan's autoplay for the step.

## Route control

DicyaninStageDirector routes for capture: `workshop/assembly/watch`, `workshop/assembly/step/<n>`,
`workshop/assembly/done`. Ready marker fires when the step is locked.

## Tests

- `AssemblyPlanTests`: plan from each mission reference craft reproduces that craft exactly
  (same stack, radial, counts) when all steps apply.
- Target transforms match `CraftBuilder.build` positions within 1 mm.
- Rewind from step k leaves the craft equal to the plan applied to k - 1.
- Wrong-part lock is rejected; free-build lock goes through `addBlock` cap checks.

## Order of work

1. `AssemblyPlan` and tests.
2. Racks with real parts, ghost and ring, Watch build with transport.
3. Manual pick, snap, lock, detach.
4. Tip cards and tour update.
5. Two-hand large parts, tabletop gestures, routes.

## Open

- Hand tracking (ARKit `HandTrackingProvider`) for heavy-lag follow versus plain `DragGesture` on
  the entity. Plan uses `DragGesture` with `targetedToAnyEntity()` first; hand tracking only if lag
  feel needs it.
- Aircraft assembly order (fuselage first, wings radial) uses the same plan shape; spec covers
  rockets only until M4.
