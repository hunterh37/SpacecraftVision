# Lab UI: blocks, syntax colour, trace

Native SwiftUI surfaces for the coding stage. Package `LabUI` (in `SpacecraftKit`), hosted by `CodeEditorView`.

## Pieces

| Piece | Where | Notes |
|---|---|---|
| Block model | `Curriculum/Blocks.swift` | Codable. `BlockSpec` (lines + visual nodes), `BlockKnob` (tunable number), `BlockProgram` (scaffold, specs, knobs, solution) |
| Lesson palettes | `Curriculum/LessonBlocks.swift` | Lessons 0 to 2. Scaffolds are cut from the reference code, so the solution order with reference values flies exactly like the reference |
| Trace | `FlightCode/VM.swift` `traceHook`, `FlightRunner/Tracer.swift` | One guidance tick, step by step: line, variables, craft calls, instruction use. Deterministic |
| Workspace | `LabUI/CodeWorkspace.swift` | Tabs: Blocks, Python, Trace. `CodeWorkspaceModel` owns the script and the generated source |
| Views | `LabUI/BlockViews.swift`, `CodeSurface.swift`, `TraceView.swift` | Scratch-like shapes, coloured code with error popup, trace panel |
| Theme | `LabUI/LabTheme.swift` | Panels carry their own aurora, light shaft, grain and frame lines. No page background is assumed |

## Rules

- Blocks compose into the lesson scaffold; the source then goes through the normal compile and preview path (`AppModel.sources`).
- Editing Python by hand detaches the blocks. "Back to blocks" re-composes.
- A runtime or compile error line is mapped back to the block that produced it (`ComposedSource.origins`).
- The trace hook costs one optional check per VM instruction when unset. Lines with `line == 0` (implicit returns) are never traced.
- `Tools/LabPreview` renders the workspace in the visionOS simulator without RealityHD.

## Not done yet

- Lessons 3 to 10: `craft.lidar` and `craft.lidar_scan` are stubs that return no data (`ScriptGuidance`), so obstacle avoidance cannot run yet. Our reactive ray-sensing and potential-field blocks and traces are ready to port once the lidar is real.
- Stage 2 still uses the tap-to-order text list; it should use `BlockShape` pieces from the same `BlockSpec`s.
- RealityKit overlays for rays, force arrows and clearance-coloured trails (`SpacecraftRender`).
