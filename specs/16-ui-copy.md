# UI copy

All player-facing strings for v1, English. Source for `Localizable.xcstrings`. Keys are
`area.item`. Placeholders use `{name}`; numbers are formatted by the app with units from
`14-parts-catalog.md`. Style: sentence case, plain statements, no exclamation marks.

## Lesson titles

| Key | Lesson | Title | Subtitle |
|---|---|---|---|
| `lesson.0.title` | 0 | Loops and state | Cut the engine at the right height |
| `lesson.1.title` | 1 | Feedback | Hold the pitch with a P controller |
| `lesson.2.title` | 2 | PID | Steer through five gates |
| `lesson.3.title` | 3 | Reactive avoidance | Bug 0 around walls |
| `lesson.4.title` | 4 | Bug 2 | Follow the line, follow the wall, leave |
| `lesson.5.title` | 5 | Potential fields | Pulled by the goal, pushed by obstacles |
| `lesson.6.title` | 6 | Vector field histogram | Find the open valley |
| `lesson.7.title` | 7 | Velocity obstacles | Dodge moving debris |
| `lesson.8.title` | 8 | Grid planning | A* through the canyon |
| `lesson.9.title` | 9 | Sampling planning | Grow a tree through the debris |
| `lesson.10.title` | 10 | Capstone | Your algorithm, a new course |

Stage names: `stage.concept` Concept, `stage.pseudocode` Pseudocode, `stage.implement` Implement,
`stage.run` Run, `stage.analyze` Test and analyze.

## Concept narration

One line per caption card. The narrator reads each line; captions show the same text.

### Lesson 0

1. A rocket does the same small job many times a second. That repeated job is a loop.
2. Your code runs fifty times each second. Each run is one tick.
3. The rocket also needs to remember what it is doing: climbing, coasting or falling. That memory is
   the state.
4. In the diorama, tap the steps to move the rocket from boost to coast to parachute.
5. Cut the engine too late and the rocket flies too high. Too early and it falls short.

### Lesson 1

1. Wind pushes the rocket off its path. The rocket has to notice and push back.
2. Measure the error: the pitch you want minus the pitch you have.
3. Turn at a rate proportional to that error. Big error, fast turn. Small error, slow turn.
4. The number that sets how hard you push back is the gain, KP.
5. Balance the stick in the diorama. Watch what happens when your corrections are too small or too
   large.

### Lesson 2

1. A P controller can leave a steady error, and it can overshoot.
2. The integral term adds up past error and removes the steady offset.
3. The derivative term looks at how fast the error is changing and damps overshoot.
4. Together they are PID: proportional, integral, derivative.
5. Steer the cart to the line using all three dials and watch the response change.

### Lesson 3

1. The rover knows where home is. It does not have a map.
2. Rule one: drive toward the goal.
3. Rule two: if something is closer than a safe distance ahead, turn toward the more open side.
4. Rule three: as soon as the way to the goal is clear, head for the goal again.
5. This is Bug 0. Steer three rovers home by hand, then watch the rule do it.

### Lesson 4

1. Bug 0 can circle forever around some shapes. Bug 2 adds memory.
2. Draw a line from start to goal. This is the M-line.
3. Follow the M-line. When you hit an obstacle, remember how far the goal is.
4. Follow the obstacle's edge until you meet the M-line again closer to the goal.
5. Then leave the edge and continue on the line. Guide the rover around the wall shapes.

### Lesson 5

1. Imagine the goal pulls on the craft like a spring.
2. Every obstacle pushes back, harder the closer you get.
3. Add the pull and the pushes. Steer along the sum.
4. Some shapes create a spot where pull and push cancel. This is a local minimum.
5. Roll the marble down the slope and find where it gets stuck.

### Lesson 6

1. The lidar returns thirty-six distances around the craft.
2. Group them into sectors and add up how crowded each sector is. This is a polar histogram.
3. Sectors below a threshold are free. Neighbouring free sectors form a valley.
4. Pick the valley closest to the goal direction and steer into it.
5. Lower the bars in the diorama and choose a heading through the gaps.

### Lesson 7

1. Debris moves. Avoiding where it is now is not enough.
2. For each velocity you could choose, predict where you and the debris will be.
3. If you would come too close within the time horizon, that velocity is inside the collision cone.
4. Choose the allowed velocity closest to the one you want.
5. Drag the velocity arrow in the diorama out of every cone.

### Lesson 8

1. Turn the world into a grid. Each lidar hit fills a cell.
2. Grow the filled cells by the craft's size so the path keeps clearance.
3. A* searches outward from the craft, always expanding the cell with the lowest cost so far plus
   the straight-line distance left.
4. When new cells fill, plan again.
5. Flip tiles in the diorama and watch the flood find the shortest way.

### Lesson 9

1. Some spaces are too large or move too fast for a grid.
2. Pick random points. Connect each to the nearest branch of a tree, one short step at a time.
3. Throw away any step that would hit an obstacle.
4. When a branch reaches the goal, cut corners to straighten the path.
5. Grow the tree in the diorama and watch it find a way through.

### Lesson 10

1. A new course is generated for you.
2. Choose any algorithm you have built and adapt it.
3. You are scored on energy used and time taken.

## Mini games

| Key | Lesson | Name | Rules |
|---|---|---|---|
| `mini.stairs` | 0 | Throttle stairs | Tap a step to set the phase. Reach the target height band on the wall chart within 3 tries |
| `mini.balance` | 1 | Balance stick | Pinch and move left or right to keep the stick within 10 deg of vertical for 20 s while gusts push it. A gain dial replaces your hand in round 2 |
| `mini.cart` | 2 | Steer the cart | Set the P, I and D dials, then release the cart. Settle on the line within 5 s without crossing it more than once |
| `mini.hand-steer` | 3, 4 | Hand steering | Pinch left or right to steer a rover around blocks to its home pad. Get 3 rovers home. Round 2 plays the Bug rule for comparison |
| `mini.marble` | 5 | Marble on a slope | Pinch to place obstacle hills on a sloped table; the marble rolls to the goal. Find one placement that traps it |
| `mini.polar-bars` | 6 | Polar bars | Bars around the craft show crowding. Drag the threshold line, then pick a heading through a gap at least 3 sectors wide |
| `mini.cones` | 7 | Cones of collision | Drag the velocity arrow so its tip sits outside every cone for 3 waves of debris |
| `mini.flood` | 8 | Flood tiles | Tap tiles to place walls; press Flood to watch A* expand. Reach the goal with the fewest expanded tiles |
| `mini.tree` | 9 | Growing tree | Pinch to drop sample points; the tree extends toward each. Reach the top of the volume in 30 samples or fewer |

Mini game result strings: `mini.pass` "Done.", `mini.retry` "Try again.", `mini.auto` "Watch the
rule run."

## Failure messages

Shown on the cause card (`07-failure-rules.md`). Title, then body. `{line}` is the code line active
at the failure tick.

| Key | Rule | Title | Body |
|---|---|---|---|
| `fail.launch-twr` | Launch TWR | Not enough thrust | Thrust to weight at ignition was {value}. It must be at least 1.0. Remove mass or add thrust. |
| `fail.mass` | Mass limit | Too heavy | Wet mass {value} kg is over the mission cap of {limit} kg. |
| `fail.part-list` | Part list | Part not allowed | {part} is not on this mission's part list, or the craft has {value} parts against a cap of {limit}. |
| `fail.budget` | Budget | Over budget | Craft cost {value} cr is over the mission budget of {limit} cr. |
| `fail.energy` | Energy | Out of energy | Battery reached 0 Wh at {time} s with {value} W still drawing. Sensors and actuators stopped. Line {line}. |
| `fail.overheat` | Overheat | {part} overheated | {part} reached {value} K. Its limit is {limit} K. Line {line}. |
| `fail.structural` | Structural | {part} broke off | Joint load {value} kN was over the {limit} kN limit. Line {line}. |
| `fail.aero` | Aero overload | {part} tore away | Dynamic pressure {value} kPa was over the {limit} kPa limit. Slow down or remove the part. Line {line}. |
| `fail.collision` | Collision | Collision with {obstacle} | Impact at {value} m/s. Closest clearance before impact was {clearance} m. Line {line}. |
| `fail.corridor` | Corridor | Left the course | The craft was outside the corridor for 2 s. Line {line}. |
| `fail.landing` | Landing | Hard landing | Touchdown at {value} m/s, tilt {tilt} deg. Limits are 6 m/s and 15 deg. |
| `fail.chute` | Parachute deploy | Parachute torn | {stage} deployed at {value} m/s. The limit is {limit} m/s. |
| `fail.runtime` | Runtime | Code stopped responding | 50 guidance ticks in a row were skipped. Last fault: {fault} at line {line}. |

Runtime fault strings (editor and telemetry): `fault.div0` "Division by zero", `fault.index` "Index
{index} out of range for length {length}", `fault.key` "Key {key} not in dict", `fault.budget`
"Tick used more than 100,000 instructions", `fault.recursion` "Recursion deeper than 64", `fault.heap`
"Memory over 1 MB", `fault.type` "Expected {expected}, got {actual}", `fault.sensor` "{call} needs a
{part}; it returns {empty} without one".

Workshop launch blockers use the same titles with prefix "Cannot launch. ".

## Part stat tooltips

| Key | Stat | Tooltip |
|---|---|---|
| `stat.mass-dry` | Dry mass | Mass with empty tanks, in kg. |
| `stat.mass-wet` | Wet mass | Mass with tanks at the set fuel load, in kg. |
| `stat.size` | Size | Diameter and length in metres. |
| `stat.cost` | Cost | Credits counted against the mission budget. |
| `stat.unlock` | Unlocks at | The lesson that adds this part to the rack. |
| `stat.nodes` | Attach nodes | Where other parts connect. S0 is 0.625 m, S1 is 1.25 m. |
| `stat.max-temp` | Max temperature | Above this the part is destroyed, in kelvin. |
| `stat.joint` | Joint limit | Force the connection to the parent can carry, axial and sideways, in kN. |
| `stat.max-g` | Max g | Acceleration the part's contents survive. |
| `stat.max-q` | Max q | Air pressure from speed the part survives while exposed, in kPa. |
| `stat.thrust` | Thrust | Force at sea level and in vacuum, in N. |
| `stat.isp` | Isp | Seconds of thrust per unit weight of propellant. Higher uses less fuel. |
| `stat.burn` | Burn time | Time at full throttle on the attached tank. |
| `stat.gimbal` | Gimbal | How far the nozzle tilts to steer, in degrees. |
| `stat.throttle` | Throttle range | Lowest and highest throttle. Below the lowest the engine is off. |
| `stat.battery` | Capacity | Stored energy in Wh and the most power it can supply. |
| `stat.solar` | Solar output | Power in full sun facing the panel, in W. |
| `stat.draw` | Power draw | Power used while running, in W. |
| `stat.range` | Range | Farthest detection distance, in m. |
| `stat.fov` | Field of view | Angles the sensor covers. |
| `stat.rate` | Update rate | New readings per second. |
| `stat.noise` | Noise | Typical error of one reading. |
| `stat.drag` | Drag | Frontal area and drag coefficient. Higher means more air resistance. |
| `stat.source` | Based on | Real hardware the values come from. |

Stat board readouts (`02-workshop.md`): `board.twr` "TWR", `board.dv` "Delta-v {stage}",
`board.com` "Centre of mass", `board.cot` "Centre of thrust", `board.col` "Centre of lift",
`board.parts` "Parts {value} / {limit}", `board.budget` "Cost {value} / {limit} cr",
`board.heat` "Lowest heat limit {value} K", `board.energy` "Energy {value} / {limit} Wh".

## Buttons and labels

| Key | Label | Where |
|---|---|---|
| `btn.launch` | Launch | Range, workshop |
| `btn.abort` | Abort | Range |
| `btn.pause` | Pause | Range |
| `btn.resume` | Resume | Range |
| `btn.speed-025` | 0.25x | Range |
| `btn.speed-1` | 1x | Range |
| `btn.speed-4` | 4x | Range |
| `btn.view-ground` | Ground | Range |
| `btn.view-chase` | Chase | Range |
| `btn.view-tabletop` | Tabletop | Range |
| `btn.view-sensor` | Sensor | Range |
| `btn.replay` | Replay | Range, analysis |
| `btn.compare` | Compare | Analysis |
| `btn.export` | Export | Analysis |
| `btn.run` | Run | Code |
| `btn.reset-code` | Reset to starter | Code |
| `btn.blocks` | Blocks | Code |
| `btn.text` | Text | Code |
| `btn.language-python` | Python | Code |
| `btn.language-c` | C | Code |
| `btn.hint` | Hint | Code, after 3 failed runs |
| `btn.check` | Check | Pseudocode stage |
| `btn.build` | Workshop | Main |
| `btn.missions` | Missions | Main |
| `btn.lessons` | Lessons | Main |
| `btn.crafts` | Saved crafts | Main |
| `btn.save-craft` | Save craft | Workshop |
| `btn.scale` | Tabletop scale | Workshop |
| `btn.symmetry` | Symmetry {n}x | Workshop |
| `btn.next-stage` | Next | Lesson |
| `btn.back` | Back | All |
| `btn.settings` | Settings | Main |
| `btn.replay-tips` | Replay tips | Settings |
| `btn.done` | Done | Sheets |

Result strings: `result.pass` "Mission passed", `result.stars` "{n} of 3 stars", `result.score`
"Score {value}", `result.new-best` "New best". Hint levels: `hint.1` "Failing test: {test}",
`hint.2` "Look at lines {from} to {to}", `hint.3` "Pseudocode difference".
Compile status: `compile.ok` "Compiled", `compile.error` "{count} errors".
