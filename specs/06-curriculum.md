# Curriculum

Each lesson runs five stages: Concept, Pseudocode, Implement, Run, Test and analyze. A lesson is
complete when its mission passes and the analysis question is answered.

## Lessons

| # | Topic | Algorithm | Mission | Sensors |
|---|---|---|---|---|
| 0 | Loops and state | Throttle schedule by altitude | M1 hop | imu |
| 1 | Feedback | P controller holding a pitch program | M1W hop in wind | imu |
| 2 | PID | PID on heading to the next gate | M2 gates | imu, `next_gate` |
| 3 | Reactive avoidance | Bug 0: head to goal, turn on contact range, resume | M2B gates and walls | lidar |
| 4 | Bug 2 | M-line follow, wall following, leave condition | M4 field | lidar |
| 5 | Potential fields | Attractive goal plus repulsive obstacles, local minima | M4 field | lidar_scan |
| 6 | Vector field histogram | Polar histogram, valley pick | M5 canyon | lidar_scan |
| 7 | Velocity obstacles | Moving obstacles, closing speed | M6 debris | radar |
| 8 | Grid planning | A* on an occupancy grid from scans, replan | M5 canyon | lidar_scan |
| 9 | Sampling planning | RRT in 3D with smoothing | M6 debris | radar, camera |
| 10 | Capstone | Player choice, scored on energy and time | M7 generated course | any |

Missions, courses, starter code and reference solutions: `15-missions-courses.md`. Narration and
mini game copy: `16-ui-copy.md`. M3 drift is an optional practice mission unlocked after lesson 2.
The playable M1T and M1P Missions compare an open-loop timer with drag-aware apogee prediction on
the hop course, then change payload and budget so players must retune their guidance and build.

## Stage detail (lesson 3 as example)

1. Concept. A tabletop volume shows a rover and blocks. The player steers it by pinching left or right
   while a narrator voice and captions state the Bug 0 rule. Mini game: get 3 rovers home by hand,
   then watch the rule do it.
2. Pseudocode. Blocks: `loop`, `if obstacle closer than D`, `turn away`, `else head to goal`. Grader
   runs the block tree on 5 seeded maps; 4 of 5 must pass.
3. Implement. Starter code holds the pseudocode as comments and stubs. Hidden tests call `update`
   with recorded sensor frames and check commands.
4. Run. Live flight on the mission course.
5. Analyze. Plot closest obstacle distance over time. Question: which constant sets the minimum
   clearance, and what happens to fuel when it doubles? Player runs both and answers from plots.

## Mini game catalog

Throttle stairs (lesson 0), balance stick (1), steer the cart (2), hand steering (Bug, 3 and 4),
marble on a slope (potential fields, local minimum trap, 5), polar bars (histogram, 6), cones of
collision (velocity obstacles, 7), flood tiles (A*, 8), growing tree (RRT, 9). Rules in
`16-ui-copy.md`. Lesson 10 has no mini game.

## Grading

| Signal | Weight |
|---|---|
| Mission pass | required |
| Hidden unit tests | 40% |
| Fuel used vs par | 20% |
| Min clearance vs par | 20% |
| Analysis answer | 20% |

Stars 1 to 3 at 60, 80, 95 percent. Par values per mission are in `15-missions-courses.md`. The
pseudocode grader runs the block tree on 5 seeded 2D maps per lesson; 4 of 5 must pass. Analysis
answers are multiple choice with 4 options, graded right or wrong. Hints unlock after 3 failed runs: first the failing test name,
then the line range, then a pseudocode diff. Solutions never show in full.

## Educator mode (v1.1)

Export per-student progress as CSV; lock lessons; custom course files.
