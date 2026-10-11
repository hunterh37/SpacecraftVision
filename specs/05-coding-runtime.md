# Coding runtime

## Language choice

| Language | v1 | Reason |
|---|---|---|
| Python subset | yes | First language in most courses; readable for pseudocode transfer |
| C subset | yes | Embedded flight software is written in C; teaches types and fixed loops |
| Ada | v2 | Used in avionics (SPARK); niche audience |
| MATLAB-like | v2 | Familiar to engineering students; plots already MATLAB style |

Running CPython or a C compiler on visionOS is ruled out: no JIT, App Review rule 2.5.2 limits
downloaded executable code, and binary size. Both subsets compile to one shared IR and a register
bytecode VM written in Swift (`FlightCode` package). User code is data interpreted inside the app.

## Python subset

Supported: `def`, `if/elif/else`, `while`, `while True`, `for x in range(...)`, `for x in list`,
`return`, `break`, `continue`, `pass`, int, float, bool, `None`, str (log, plot names and dict keys),
list, tuple, dict with str or int keys, tuple unpacking in assignment, module-level variables read
and mutated in place (no `global` statement), `import craft`, `import math`.

Operators: `+ - * / // % **`, `+= -= *= /=`, comparisons, `and or not`, `in` and `not in` on dict
keys and lists, `is None`, indexing and negative indexing, line continuation inside brackets.

Builtins: `abs min max len range int float round str`, list `append pop insert`, dict `get keys`.

`math`: `sin cos tan asin acos atan atan2 sqrt hypot (2 or 3 args) floor ceil exp log pi inf
radians degrees clamp(x, lo, hi)`.
Unsupported: classes, exceptions, generators, comprehensions in v1 (comprehensions in v1.1),
file and network access, `eval`.

## C subset

Supported: `int`, `double`, `bool`, fixed arrays, structs, functions, `if`, `for`, `while`,
`switch`, `const`, `#include <craft.h>` and `<math.h>` as virtual headers. No pointers in v1 except
array parameters; no `malloc`. Static types are checked; errors use gcc-style messages with line
and column.

Implementation: `FlightCode/CCompiler.swift` type-checks C and lowers it to the Python-subset syntax
tree, then the shared generator emits the same bytecode for the same VM (`Compiler.compile(source,
language: .c)`, `ScriptGuidance(source:language:)`). Errors read `line:col: error: message`.

`<craft.h>` mapping (one function per craft call, `vec3` is `struct { double x, y, z; }`):

| C | Python |
|---|---|
| `double craft_altitude()`, `craft_fuel`, `craft_energy`, `craft_time`, `craft_mass`, `craft_thrust_max`, `craft_random`, `craft_temperature` | `craft.altitude()` ... |
| `vec3 craft_position()`, `craft_velocity`, `craft_attitude` (x pitch, y yaw, z roll), `craft_next_gate` / `craft_goal` (x bearing, y elevation, z distance), `craft_goal_position` | tuple results |
| `void craft_set_throttle(double)`, `craft_set_pitch`, `craft_set_yaw`, `craft_set_roll`, `craft_stage(void)` | commands |
| `void craft_log(x)`, `void craft_plot("name", double)` | string literals only here |
| `double craft_lidar(double angle_deg)` | `craft.lidar(a)` |
| `int craft_lidar_scan(double angles[], double dists[])` | fills both arrays (36 entries), returns the count; only as a statement or assignment right side |

`craft_radar`, `craft_radar_tracks` and `craft_camera_objects` are Python only in v1.
`<math.h>`: `sin cos tan asin acos atan atan2 sqrt hypot exp log floor ceil fabs copysign pow fmin
fmax`, `M_PI`, `INFINITY`, plus the craft helpers `radians`, `degrees`, `clamp(x, lo, hi)`.
Semantics: `int / int` and `%` truncate toward zero; struct and array assignment shares storage
(no copy); `continue` inside `switch` and assignment inside expressions are rejected. Lesson 0 and 1
C references: `Curriculum/LessonCodeC.swift`, checked against the Python command streams in
`FlightRunnerTests/CLessonTests.swift`.

## Program contract

Both languages expose the same entry points:

```python
import craft

def setup():
    pass                      # once, before launch

def update(dt):
    pass                      # every guidance tick, dt = 0.02 s
```

```c
#include <craft.h>
void setup(void) {}
void update(double dt) {}
```

## Craft API

| Call | Returns | Notes |
|---|---|---|
| `craft.position()` | vec3 m | Course frame, noise per sensor tier |
| `craft.velocity()` | vec3 m/s | |
| `craft.attitude()` | (pitch, yaw, roll) rad | pitch = nose above horizontal, yaw = compass heading from +y toward +x, roll right positive. Tier 0 from probe-core, tier 1 from `imu` |
| `craft.altitude()` | m | |
| `craft.fuel()` / `craft.energy()` | 0..1 | |
| `craft.temperature(part)` | K | |
| `craft.lidar(angle_deg)` | m or -1 | Requires `lidar-sensor`. Horizontal stabilized plane, angle relative to heading, positive right. 120 m, 10 Hz |
| `craft.lidar_scan()` | list of (angle_deg, dist) | 36 rays from -180 to 170 in 10 deg steps; dist -1 for no return |
| `craft.radar()` | list of (bearing, elevation, range, closing_speed) | Requires `radar-sensor`; rad about the nose axis; 2 km, 20 Hz |
| `craft.radar_tracks()` | list of (rel_pos vec3, rel_vel vec3, radius) | Requires `radar-sensor`; course-frame vectors of obstacle minus craft; moving obstacles only |
| `craft.camera_objects()` | list of (id, bearing, elevation, size) | Requires `camera-sensor`; rad about the nose axis, size = angular size rad |
| `craft.next_gate()` | (bearing, elevation, distance) | Bearing relative to yaw. (0, 0, -1) when no gates remain. Available lessons 0 to 7 |
| `craft.goal()` | (bearing, elevation, distance) | To the finish point |
| `craft.goal_position()` | vec3 m | Finish point, course frame |
| `craft.time()` | s | Since the first `update` |
| `craft.mass()` | kg | Current total mass |
| `craft.thrust_max()` | N | Sum of active engine thrust at full throttle at current ambient pressure |
| `craft.random()` | 0..1 | Seeded from the flight seed; same sequence in preview and live |
| `craft.set_throttle(x)` | | 0..1 |
| `craft.set_pitch(r)` / `set_yaw` / `set_roll` | | Rate commands in rad/s, tracked by the built-in rate loop (`07b-physics-model.md`). Limits: rocket pitch and yaw 0.5, roll 1.0; aircraft pitch 0.6, roll 1.5; aircraft `set_yaw` is a heading rate flown as a coordinated turn, limit 0.25 (45 deg bank at 35 m/s). Commands hold until changed |
| `craft.stage()` | | Fire the next item in the craft's stage list (decoupler, engine ignition, drogue, main) |
| `craft.log(value)` | | Telemetry ornament and record |
| `craft.plot(name, value)` | | Adds a named series to analysis |

Missing sensor part: call returns the empty value (-1, empty list, or (0, 0, 0)) and logs
`fault.sensor` once (`16-ui-copy.md`). vec3 is a tuple (x, y, z).

## Sandbox

Instruction budget 100,000 per tick and 5,000,000 for `setup()`, 1 MB heap cap, recursion depth 64, no host calls outside the API table.
Runtime faults (division by zero, index out of range, budget exceeded) do not crash the flight; the
tick is skipped and the fault is shown with its line in the editor.

## Editor

Block mode (stage 2): pseudocode blocks snap into a tree; each block maps to a statement template.
Text mode (stage 3): monospaced editor with syntax highlighting, inline errors, autocomplete for the
craft API, and a hardware keyboard requirement noted in onboarding (virtual keyboard supported).
The pseudocode from stage 2 is shown as comments in stage 3 starter code.

## Preview

Compile then simulate headless at up to 10x; results stream to the range ribbon. Determinism:
fixed seed, fixed step, VM float ops in Double, same order on every run.
