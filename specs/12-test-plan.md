# Test plan

| Area | Tests |
|---|---|
| SpacecraftCore | Mass, CoM and inertia for known stacks; attach rules; symmetry |
| FlightSim | Reference trajectories (`07b-physics-model.md`); determinism (same seed, bit-equal records); each failure rule triggered by a fixture craft |
| FlightCode | Parser golden files per construct; error messages and positions; VM opcode tests; budget and recursion limits; Python and C versions of each lesson solution produce identical command streams |
| Curriculum | Reference solution passes each lesson; known wrong solutions fail with the expected test |
| Render | `realityhd gate` for each new asset; offscreen renders of workshop and range compared against committed baseline PNGs, fail above 2% pixel difference (per-channel delta over 8) |
| UI | DicyaninStageDirector routes for every scene; screenshots via /vision-screenshot |
| Performance | Device frame time: workshop under 11 ms, range under 11 ms with full course; preview sim of 60 s flight under 1 s on M2/M5 |

Packages without RealityKit run under `swift test` on macOS in CI.
