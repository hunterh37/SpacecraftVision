# Flight test

## Range

Full ImmersiveSpace. Desert launch site with pad, tower, blockhouse and a runway for aircraft.
RealityHD terrain, rocks, scrub, sky at the mission time of day. The player stands on a viewing
platform 60 m from the pad at true scale.

## Courses

A course is data (`11-data-model.md`): obstacles with shape, pose, motion path and a corridor
volume. Obstacle types: ring gate, pylon, balloon, wall with gap, canyon walls, debris rock with
spin and drift, no-fly cylinder (a red translucent volume, corridor-type rule, no collision mesh;
unused by v1 courses, available to custom courses). Courses scale from 200 m to 12 km. Every v1
course (C1 to C7) is defined in `15-missions-courses.md`. Rockets start on the pad; aircraft start
in the air at 35 m/s (catapult convention).

## Views

| View | Description |
|---|---|
| Ground | True scale from the platform |
| Chase | Player rides 15 m behind the craft; comfort vignette fades in above 30 deg/s camera yaw or pitch rate, full at 90 deg/s |
| Tabletop | Whole course shrunk to a 2 m diorama in front of the player, craft as a marker |
| Sensor | Craft sensor rays and detected obstacles drawn as lines and boxes |

Chase view is opt-in and limited by the comfort settings. Default flight view is ground for courses
under 1,500 m extent (C1, C2, C2B, C3) and tabletop for the rest.

## Preview path

Before launch the predicted trajectory is a ribbon through the course. Color by speed. Red segment
marks the predicted failure point with its cause label. Editing code updates the ribbon after
compile (target under 1 s for a 60 s flight).

## Live flight

Controls: Launch, Abort, Pause, 0.25x / 1x / 4x time. Telemetry ornament: altitude, speed,
throttle, fuel, energy, max part temperature, current guidance state string set by the player's
code via `log()`.

## Replay

Every run replays from its `FlightRecord` with a scrubber. Two runs overlay as ghost and live with
a divergence marker at the first tick where positions differ by more than 1 m.
