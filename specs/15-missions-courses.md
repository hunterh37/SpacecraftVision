# Missions and courses

Every mission and course referenced by `02-workshop.md`, `03-flight-test.md` and `06-curriculum.md`.
Source for `Resources/Data/missions.json`, `courses.json` and `lessons.json` (`11-data-model.md`).
Part constants come from `14-parts-catalog.md`. Starter and reference code use the Python subset
and craft API in `05-coding-runtime.md`. C versions are line-for-line translations written in M4
and must produce identical command streams (`12-test-plan.md`).

## Frames and conventions

| Item | Rule |
|---|---|
| Course frame | Origin at the pad centre (rocket courses) or the air-start point projected to the ground (aircraft courses). x east, y north, z up, metres. Terrain at z = 0 unless stated |
| Attitude | pitch = nose elevation above horizontal (rocket on pad = pi/2). yaw = compass heading of the nose, 0 = +y, positive toward +x. roll = right bank positive. Rocket on the pad has yaw 0 |
| Bearings | API bearings are relative to current yaw, radians, positive right, wrapped to [-pi, pi]. Lidar angles are degrees, same sign |
| Rocket start | On the pad, engine off, upright, t = 0 at the first `update` call |
| Aircraft start | Air start (catapult convention): position (0, 0, start altitude), heading 0, 35 m/s, wings level, throttle 0.5. Runway takeoff is a v1.1 option |
| Payload | Mass added to the root part, no geometry |
| Corridor | `tube`: polyline plus radius. `box`: polyline in plan view plus half width, floor z and ceiling z. Outside for more than 2 s ends the flight (`07-failure-rules.md`) |
| Gate pass | Craft centre of mass crosses the gate plane inside the inner radius, gates in order, no contact |
| Finish | Crossing the finish plane after all gates; flight ends with Pass if all criteria hold |
| Wind | Steady vector (direction it blows from, compass degrees, and speed at 10 m) with power-law shear exponent 0.14, plus Dryden gusts: none, light (sigma 1.0 m/s), moderate (2.0 m/s), seeded by the course seed |
| Score | `06-curriculum.md` weights. Fuel component = 20 x min(1, par fuel / used fuel). Clearance component = 20 x min(1, min clearance / par clearance). Stars at 60, 80, 95 |

Prop scaling: `ring-gate` is authored at 8 m outer diameter, inner radius 3.5 m. A course gate with
inner radius r uses uniform scale r / 3.5; its base frame is hidden above 20 m. `gap-wall`,
`pylon` and `canyon-wall` take size parameters per obstacle (`04-realityhd-assets.md`).

## Mission table

| Id | Title | Lesson | Craft | Course | Payload kg | Mass cap kg | Part cap | Budget cr | Energy cap Wh | Fuel load |
|---|---|---|---|---|---|---|---|---|---|---|
| `M1` | Hop | 0 | Rocket | `C1` | 20 | 450 | 12 | 20,000 | 2,500 | fixed 10% |
| `M1W` | Hop in wind | 1 | Rocket | `C1W` | 20 | 450 | 12 | 20,000 | 2,500 | fixed 10% |
| `M1T` | Clockwork hop | optional challenge | Rocket | `C1` | 20 | 450 | 12 | 20,000 | 2,500 | fixed 10% |
| `M1P` | Predictive hop | optional challenge | Rocket | `C1` | 35 | 450 | 12 | 19,000 | 2,500 | fixed 10% |
| `M2` | Gates | 2 | Rocket | `C2` | 20 | 1,600 | 16 | 26,000 | 2,500 | free |
| `M2B` | Gates and walls | 3 | Rocket | `C2B` | 20 | 1,600 | 16 | 30,000 | 2,500 | free |
| `M3` | Drift | practice after 2 | Rocket | `C3` | 20 | 1,600 | 16 | 26,000 | 2,500 | free |
| `M4` | Field | 4, 5 | Aircraft | `C4` | 20 | 600 | 18 | 28,000 | 5,000 | n/a |
| `M5` | Canyon | 6, 8 | Aircraft | `C5` | 20 | 600 | 18 | 28,000 | 5,000 | n/a |
| `M6` | Debris | 7, 9 | Rocket | `C6` | 50 | 3,600 | 20 | 34,000 | 2,500 | free |
| `M7` | Capstone | 10 | Aircraft | `C7-<seed>` | 40 | 650 | 20 | 40,000 | 7,500 | n/a |

## Allowed parts

| Mission | Allowed parts |
|---|---|
| `M1`, `M1W`, `M1T`, `M1P` | probe-core, imu, battery-pack, nose-cone, fuel-tank-s, engine-liquid-small, fin-trapezoid, parachute |

| `M2`, `M3` | M1 list plus fuel-tank-m, decoupler |
| `M2B` | M2 list plus lidar-sensor |
| `M4`, `M5` | probe-core, imu, battery-pack, nose-cone, fuselage-section, engine-prop, wing-section, elevon, fin-trapezoid, landing-gear, solar-panel, lidar-sensor |
| `M6` | M2B list plus fuel-tank-l, engine-solid-small, radar-sensor, camera-sensor |
| `M7` | M4 list plus camera-sensor, radar-sensor |

`M1T` and `M1P` are playable comparison challenges implemented in `Curriculum/AlgorithmChallenges.swift`.
`M1T` stops the engine after a timed burn and targets a 1,050–1,150 m apogee. `M1P` uses height,
vertical speed and a tunable atmospheric correction to predict apogee for a 35 kg payload; it targets
1,080–1,120 m. Both use the C1 landing zone and have failing starters and passing reference scripts.

## Reference crafts

Used by the reference solutions and the regression suite. Players may build others.

| Craft | Parts (top to bottom, then radial) | Dry kg | Wet kg | Cost cr | TWR SL |
|---|---|---|---|---|---|
| `R-hop` | nose-cone, probe-core (imu, battery-pack, parachute surface), fuel-tank-s at 10%, engine-liquid-small, 4 fin-trapezoid | 289 + 20 payload | 404 | 18,700 | 6.05 |
| `R-gates` | R-hop with fuel-tank-s at 100% | 309 | 1,259 | 18,700 | 1.94 |
| `R-walls` | R-gates plus lidar-sensor on probe-core | 310 | 1,260 | 21,700 | 1.94 |
| `R-debris` | nose-cone, probe-core (imu, battery, radar, camera), fuel-tank-m, engine-liquid-small, 4 fins, 2 engine-solid-small radial on the tank | 509 + 50 payload | 3,279 | 30,700 | 1.89 |
| `A-field` | engine-prop, probe-core (imu inside), fuselage-section x2 (2 battery-pack inside, lidar on top), nose-cone reversed as tail cone, 2 wing-section default, 2 elevon, 1 fin-trapezoid vertical | 301 + 20 payload | 321 | 21,900 | n/a |

`A-field`: 8.97 m² wing, aspect ratio 9.1, wing loading 351 Pa, stall at CLmax 1.3 about 21 m/s,
cruise 35 m/s at CL 0.47, drag about 300 N, cruise power about 14 kW electrical (prop 0.80, motor
0.92), 5,000 Wh gives about 21 min. Two packs give 50 kW, so full throttle (87 kW) is capped.

## Course C1 and C1W (hop)

| Field | C1 | C1W |
|---|---|---|
| Extent | 1,000 x 1,000 m, z to 1,600 m | same |
| Corridor | tube (0, 0, 0) to (0, 0, 1,500), radius 400 m | tube (0, 0, 0) to (0, 400, 1,500), radius 500 m |
| Obstacles | none | none |
| Landing zone | circle centre (0, 0), radius 100 m, marked by 8 `pylon` (radius 0.3, height 3) on its edge | centre (0, 300), radius 250 m |
| Wind | calm | from 270 deg (blows toward +x), 5 m/s, light gusts, seed 1101 |
| Time of day | `.morning` | `.afternoon` |

Pass criteria M1: apogee between 1,000 and 1,200 m; touchdown inside the zone at 6 m/s or less.
M1W adds: pitch tracking error RMS 2 deg or less from launch to apogee; apogee 950 to 1,200 m.

Par: fuel 34 kg; clearance n/a (clearance component replaced by apogee error: 20 x max(0, 1 -
abs(apogee - 1,100) / 100)). Stars use the shared thresholds.

Reference apogee (point-mass check with drag, `R-hop`, Cd 0.45 on 1.227 m²): engine cutoff at
316 m gives 1,000 m apogee; 360 m gives 1,092 m; 419 m gives 1,200 m. The pass window is cutoff
316 to 419 m. Drogue at apogee, main below 250 m: drogue descent 27 m/s, main 6.0 m/s.

### L0 starter `lesson00_hop.py`

```python
import craft

# Lesson 0: loops and state
# Pseudocode from stage 2:
#   loop every tick:
#     if phase is boost and altitude >= CUTOFF_ALT: engine off, phase = coast
#     if phase is coast and falling: deploy drogue, phase = drogue
#     if phase is drogue and altitude < MAIN_ALT: deploy main, phase = main

CUTOFF_ALT = 150.0   # m, altitude where the engine stops. Tune this.
MAIN_ALT = 250.0     # m, altitude where the main chute opens

state = {"phase": "boost"}

def setup():
    craft.set_throttle(1.0)

def update(dt):
    alt = craft.altitude()
    vz = craft.velocity()[2]
    if state["phase"] == "boost":
        # TODO: when alt reaches CUTOFF_ALT, set throttle 0 and go to "coast"
        pass
    elif state["phase"] == "coast":
        # TODO: when vz < 0, call craft.stage() and go to "drogue"
        pass
    elif state["phase"] == "drogue":
        # TODO: when alt < MAIN_ALT, call craft.stage() and go to "main"
        pass
    craft.log(state["phase"])
    craft.plot("altitude", alt)
```

### L0 reference `lesson00_hop_ref.py`

```python
import craft

CUTOFF_ALT = 360.0
MAIN_ALT = 250.0

state = {"phase": "boost"}

def setup():
    craft.set_throttle(1.0)

def update(dt):
    alt = craft.altitude()
    vz = craft.velocity()[2]
    if state["phase"] == "boost":
        if alt >= CUTOFF_ALT:
            craft.set_throttle(0.0)
            state["phase"] = "coast"
    elif state["phase"] == "coast":
        if vz < 0.0:
            craft.stage()
            state["phase"] = "drogue"
    elif state["phase"] == "drogue":
        if alt < MAIN_ALT:
            craft.stage()
            state["phase"] = "main"
    craft.log(state["phase"])
    craft.plot("altitude", alt)
```

Hidden tests L0: `test_cutoff_in_window` (throttle 0 first commanded between 316 and 419 m),
`test_drogue_after_apogee` (stage call at vz < 0, never before), `test_main_below_250`,
`test_single_stage_per_phase`.

### L1 starter `lesson01_pitch.py`

```python
import craft
import math

# Lesson 1: feedback. A P controller holds the pitch program.
# Pseudocode from stage 2:
#   error = target pitch - measured pitch
#   pitch rate command = KP * error
#   same for yaw with target 0

CUTOFF_ALT = 360.0
MAIN_ALT = 250.0
KP = 0.0             # 1/s. Tune this. Rate limit is 0.5 rad/s.

state = {"phase": "boost"}

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def pitch_target(alt):
    if alt < 50.0:
        return math.radians(90.0)
    return math.radians(80.0)

def control(alt):
    pitch, yaw, roll = craft.attitude()
    err = pitch_target(alt) - pitch
    # TODO: command craft.set_pitch and craft.set_yaw from the errors
    craft.plot("pitch_error_deg", math.degrees(err))

def setup():
    craft.set_throttle(1.0)

def update(dt):
    alt = craft.altitude()
    vz = craft.velocity()[2]
    if state["phase"] == "boost" or state["phase"] == "coast":
        control(alt)
    if state["phase"] == "boost":
        if alt >= CUTOFF_ALT:
            craft.set_throttle(0.0)
            state["phase"] = "coast"
    elif state["phase"] == "coast":
        if vz < 0.0:
            craft.stage()
            state["phase"] = "drogue"
    elif state["phase"] == "drogue":
        if alt < MAIN_ALT:
            craft.stage()
            state["phase"] = "main"
    craft.log(state["phase"])
```

### L1 reference `lesson01_pitch_ref.py`

Starter with these changes:

```python
KP = 2.0

def control(alt):
    pitch, yaw, roll = craft.attitude()
    err = pitch_target(alt) - pitch
    craft.set_pitch(KP * err)
    craft.set_yaw(KP * wrap(0.0 - yaw))
    craft.plot("pitch_error_deg", math.degrees(err))
```

Hidden tests L1: `test_rate_sign` (positive error gives positive pitch rate), `test_proportional`
(doubling error doubles command below the clamp), `test_yaw_wrap` (yaw 6.2 rad gives a small
positive command), `test_zero_error_zero_command`.

## Course C2 (gates)

| Field | Value |
|---|---|
| Extent | 400 x 1,300 m |
| Corridor | box along (0, 0) to (0, 1,150), half width 90 m, floor 60 m (ignored for 20 s after launch), ceiling 400 m |
| Finish | plane y = 1,100 |
| Wind | calm |
| Time of day | `.afternoon` |

| Gate | Prop | Centre (x, y, z) | Inner radius m | Plane |
|---|---|---|---|---|
| G1 | `ring-gate` | (0, 200, 150) | 12 | y = 200 |
| G2 | `ring-gate` | (40, 400, 200) | 12 | y = 400 |
| G3 | `ring-gate` | (-30, 600, 250) | 12 | y = 600 |
| G4 | `ring-gate` | (60, 800, 300) | 12 | y = 800 |
| G5 | `ring-gate` | (0, 1,000, 300) | 12 | y = 1,000 |

Pass: G1 to G5 in order, finish crossed, no failure. Par: fuel 380 kg, clearance 6 m (distance from
CoM to the gate torus at each pass, minimum).

Course C3 (drift, M3) is C2 with wind from 270 deg at 8 m/s, moderate gusts, seed 3303, and gate
inner radius 15 m.

### L2 starter `lesson02_gates.py`

```python
import craft
import math

# Lesson 2: PID on heading to the next gate.
# Pseudocode from stage 2:
#   error = bearing to next gate
#   integral += error * dt
#   derivative = (error - previous error) / dt
#   yaw rate = KP * error + KI * integral + KD * derivative

G = 9.80665
CRUISE_SPEED = 12.0      # m/s horizontal
KP = 0.0
KI = 0.0
KD = 0.0
I_LIMIT = 1.0            # rad s, integral clamp
TILT_MAX = 0.35          # rad
K_V = 0.8                # 1/s, velocity error to acceleration
BRAKE = 1.5              # m/s2, planned braking when nearing the target height
VZ_MAX = 20.0            # m/s climb or sink limit

pid = {"integral": 0.0, "prev": 0.0, "first": True}

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def throttle_for_altitude(target_alt):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    err = target_alt - craft.altitude()
    vz_target = math.clamp(math.copysign(math.sqrt(2.0 * BRAKE * abs(err)), err), -VZ_MAX, VZ_MAX)
    accel = math.clamp(1.0 * (vz_target - vz), -4.0, 4.0)
    s = max(math.sin(pitch), 0.3)
    t = craft.mass() * (G + accel) / (craft.thrust_max() * s)
    # Below the 0.4 floor the engine cannot throttle down: shut it off for a moment instead.
    if t < 0.3:
        return 0.0
    return math.clamp(t, 0.4, 1.0)

def steer(bearing, target_speed):
    # Horizontal acceleration that turns the velocity toward the target at target_speed.
    # Returns (heading error to that acceleration, rad; tilt, rad). The nose tilts along its heading.
    v = craft.velocity()
    pitch, yaw, roll = craft.attitude()
    course = yaw + bearing
    ax = K_V * (target_speed * math.sin(course) - v[0])
    ay = K_V * (target_speed * math.cos(course) - v[1])
    a = math.hypot(ax, ay)
    if a < 0.2:
        return 0.0, 0.0
    err = wrap(math.atan2(ax, ay) - yaw)
    sign = 1.0
    if abs(err) > math.pi / 2.0:
        # Lean back past vertical instead of turning the heading around.
        err = wrap(err + math.pi)
        sign = -1.0
    tilt = sign * math.clamp(math.atan(a / G), 0.0, TILT_MAX) * math.cos(err)
    return err, tilt

def hold_tilt(tilt):
    pitch, yaw, roll = craft.attitude()
    craft.set_pitch(2.0 * ((math.pi / 2.0 - tilt) - pitch))

def heading_pid(err, dt):
    # TODO: return the yaw rate command from err (rad) and dt (s)
    return 0.0

def setup():
    craft.set_throttle(1.0)

def update(dt):
    bearing, elevation, dist = craft.next_gate()
    if dist < 0.0:
        bearing, elevation, dist = craft.goal()
    target_alt = craft.altitude() + dist * math.sin(elevation)
    if craft.time() < 6.0:
        target_alt = 150.0
    craft.set_throttle(throttle_for_altitude(target_alt))
    err, tilt = steer(bearing, CRUISE_SPEED)
    hold_tilt(tilt)
    craft.set_yaw(heading_pid(err, dt))
    craft.plot("heading_err_deg", math.degrees(err))
```

### L2 reference `lesson02_gates_ref.py`

Tuning (M4): the first L2 helpers held altitude with a fixed 0.8/1.2 gain pair and a 0.4 throttle
floor, so the climb to G1 reached 27 m/s and overshot the gate by 72 m; with the nose near vertical a
yaw change did not move the flight path, so G2 to G5 were missed. The helpers now brake on a square-root
approach profile (BRAKE 1.5 m/s²) and cut the engine below a 0.3 demand, and `steer()` turns the
velocity error toward the gate into a heading error and tilt, which the PID drives. Cruise 15 m/s. The
reference passes C2 with 332 kg fuel and 9.9 m minimum clearance (score 76).

Starter with these changes:

```python
KP = 1.2
KI = 0.05
KD = 0.4

def heading_pid(err, dt):
    pid["integral"] = math.clamp(pid["integral"] + err * dt, -I_LIMIT, I_LIMIT)
    if pid["first"]:
        deriv = 0.0
        pid["first"] = False
    else:
        deriv = wrap(err - pid["prev"]) / dt
    pid["prev"] = err
    return KP * err + KI * pid["integral"] + KD * deriv
```

Hidden tests L2: `test_p_term_only` (KI = KD = 0 path gives KP x err), `test_integral_accumulates`,
`test_integral_clamped`, `test_derivative_no_kick_first_tick`, `test_derivative_wraps`.

## Course C2B (gates and walls)

| Field | Value |
|---|---|
| Extent | 400 x 1,000 m |
| Corridor | box along (0, 0) to (0, 900), half width 70 m, floor 15 m (ignored for 15 s after launch), ceiling 90 m |
| Finish | plane y = 870 |
| Wind | calm |
| Time of day | `.golden` |

| Obstacle | Prop | Centre (x, y, z) | Size | Gap |
|---|---|---|---|---|
| G1 | `ring-gate` | (0, 100, 40) | inner radius 12 | |
| W1 | `gap-wall` | (0, 250, 50) | 200 wide (x), 100 tall, 2 thick | vertical slot 18 m wide centred x = +25 |
| W2 | `gap-wall` | (0, 450, 50) | 200 x 100 x 2 | slot 18 m centred x = -30 |
| W3 | `gap-wall` | (0, 650, 50) | 200 x 100 x 2 | slot 18 m centred x = +10 |
| G2 | `ring-gate` | (0, 850, 40) | inner radius 12 | |

`craft.next_gate()` points at G1 then G2. Pass: G1 and G2 in order, finish crossed, no collision.
Par: fuel 220 kg, clearance 5 m.

### L3 starter `lesson03_bug0.py`

The L2 reference helpers (`wrap`, `throttle_for_altitude`, `hold_speed_pitch`) are included
unchanged above this code, with `CRUISE_SPEED = 12.0`.

```python
# Lesson 3: Bug 0. Head to the goal; when an obstacle is close ahead, turn toward the
# more open side; resume as soon as the goal direction is clear.
# Pseudocode from stage 2:
#   loop:
#     if obstacle closer than SAFE_DIST ahead: turn away
#     else: head to goal

SAFE_DIST = 0.0       # m. Tune this.
TURN_RATE = 0.4       # rad/s
CRUISE_ALT = 40.0

bug = {"mode": "go", "side": 1.0}

def ray(angle_deg):
    d = craft.lidar(angle_deg)
    if d < 0.0:
        return 999.0
    return d

def front_range():
    return min(ray(-20.0), ray(-10.0), ray(0.0), ray(10.0), ray(20.0))

def update(dt):
    bearing, elevation, dist = craft.next_gate()
    if dist < 0.0:
        bearing, elevation, dist = craft.goal()
    craft.set_throttle(throttle_for_altitude(CRUISE_ALT))
    hold_speed_pitch(CRUISE_SPEED)
    # TODO: Bug 0 rule. Use front_range(), SAFE_DIST and bug["mode"].
    craft.set_yaw(1.0 * bearing)
    craft.plot("front_range", front_range())
```

### L3 reference `lesson03_bug0_ref.py`

```python
SAFE_DIST = 45.0

def open_side():
    left = max(ray(-30.0), ray(-50.0), ray(-70.0))
    right = max(ray(30.0), ray(50.0), ray(70.0))
    if right >= left:
        return 1.0
    return -1.0

def update(dt):
    bearing, elevation, dist = craft.next_gate()
    if dist < 0.0:
        bearing, elevation, dist = craft.goal()
    craft.set_throttle(throttle_for_altitude(CRUISE_ALT))
    hold_speed_pitch(CRUISE_SPEED)
    front = front_range()
    if bug["mode"] == "go":
        if front < SAFE_DIST:
            bug["mode"] = "turn"
            bug["side"] = open_side()
            craft.log("obstacle")
        else:
            craft.set_yaw(1.0 * bearing)
    if bug["mode"] == "turn":
        craft.set_yaw(TURN_RATE * bug["side"])
        if ray(math.degrees(bearing)) > SAFE_DIST + 20.0 and front > SAFE_DIST:
            bug["mode"] = "go"
            craft.log("resume")
    craft.plot("front_range", front)
```

Hidden tests L3: `test_go_when_clear` (all rays 999: yaw = bearing), `test_turn_on_close_front`,
`test_turn_toward_open_side`, `test_resume_when_goal_clear`, `test_no_return_minus_one_as_close`.

Analysis question L3 (`06-curriculum.md`): SAFE_DIST sets minimum clearance; doubling it raises fuel
used because the craft turns earlier and flies a longer path.

## Course C4 (field)

| Field | Value |
|---|---|
| Extent | 600 x 1,800 m |
| Start | air start (0, 0, 120), 35 m/s, heading 0 |
| Corridor | box along (0, 0) to (0, 1,700), half width 250 m, floor 30 m, ceiling 220 m |
| Goal | finish gate `ring-gate` at (0, 1,600, 120), inner radius 15 m, plane y = 1,600 |
| M-line | x = 0 from (0, 0) to (0, 1,600) |
| Wind | from 0 deg (headwind), 3 m/s, light gusts, seed 4404 |
| Time of day | `.afternoon` |

| Obstacle | Prop | Centre (x, y) | Size |
|---|---|---|---|
| W1 | `gap-wall` (no gap) | (-30, 400) | 200 long along x, 250 tall, 3 thick |
| W2 | `gap-wall` (no gap) | (40, 800) | 240 long along x, 250 tall, 3 thick |
| W3a | `gap-wall` (no gap) | (0, 1,200) | 160 long along x, 250 tall, 3 thick |
| W3b | `gap-wall` (no gap) | (80, 1,160) | 80 long along y, 250 tall, 3 thick (forms an L with W3a, a local-minimum trap for lesson 5) |
| P1 | `pylon` | (-150, 250) | radius 1.5, height 150 |
| P2 | `pylon` | (120, 300) | radius 1.5, height 150 |
| P3 | `pylon` | (-60, 600) | radius 1.5, height 150 |
| P4 | `pylon` | (150, 650) | radius 1.5, height 150 |
| P5 | `pylon` | (-180, 900) | radius 1.5, height 150 |
| P6 | `pylon` | (60, 1,000) | radius 1.5, height 150 |
| P7 | `pylon` | (-120, 1,400) | radius 1.5, height 150 |
| P8 | `pylon` | (130, 1,450) | radius 1.5, height 150 |

Pass: finish gate passed, no collision, no corridor exit. Par: energy 600 Wh (fuel component uses
energy for electric craft), clearance 8 m (measured from the 4.5 m half-span; M4 tuning).

### Aircraft helper block

Included verbatim at the top of every aircraft starter (L4, L5, L6, L8, L10).

```python
import craft
import math

CRUISE_ALT = 120.0
CRUISE_SPEED = 35.0
MAX_TURN = 0.25          # rad/s heading rate, 45 deg bank at 35 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    want = math.clamp(0.01 * (target - craft.altitude()) - 0.05 * vz, -0.2, 0.2)
    craft.set_pitch(1.5 * (want - pitch))

def hold_speed(target):
    v = craft.velocity()
    speed = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    craft.set_throttle(math.clamp(0.4 + 0.15 * (target - speed), 0.0, 1.0))

def turn(rate):
    craft.set_yaw(math.clamp(rate, -MAX_TURN, MAX_TURN))

def ray(angle_deg):
    d = craft.lidar(angle_deg)
    if d < 0.0:
        return 999.0
    return d

def front_range():
    return min(ray(-20.0), ray(-10.0), ray(0.0), ray(10.0), ray(20.0))
```

### L4 starter `lesson04_bug2.py`

```python
# Lesson 4: Bug 2.
# Pseudocode from stage 2:
#   go: follow the M-line toward the goal
#   if obstacle ahead closer than HIT_DIST: remember goal distance, switch to follow
#   follow: keep the obstacle on the right at FOLLOW_DIST
#   leave when back on the M-line and closer to the goal than at the hit point

HIT_DIST = 0.0        # m. Tune this.
FOLLOW_DIST = 0.0     # m. Tune this.
LOOKAHEAD = 150.0     # m along the M-line

bug = {"mode": "go", "hit_d": 0.0, "away": False, "sx": 0.0, "sy": 0.0, "gx": 0.0, "gy": 0.0}

def setup():
    p = craft.position()
    g = craft.goal_position()
    bug["sx"] = p[0]
    bug["sy"] = p[1]
    bug["gx"] = g[0]
    bug["gy"] = g[1]

def mline_offset():
    # signed distance from the M-line, positive to the right of start-to-goal
    p = craft.position()
    dx = bug["gx"] - bug["sx"]
    dy = bug["gy"] - bug["sy"]
    n = math.hypot(dx, dy)
    return ((p[0] - bug["sx"]) * dy - (p[1] - bug["sy"]) * dx) / n

def mline_bearing():
    p = craft.position()
    pitch, yaw, roll = craft.attitude()
    dx = bug["gx"] - bug["sx"]
    dy = bug["gy"] - bug["sy"]
    n = math.hypot(dx, dy)
    along = ((p[0] - bug["sx"]) * dx + (p[1] - bug["sy"]) * dy) / n + LOOKAHEAD
    tx = bug["sx"] + dx * along / n
    ty = bug["sy"] + dy * along / n
    return wrap(math.atan2(tx - p[0], ty - p[1]) - yaw)

def update(dt):
    hold_altitude(CRUISE_ALT)
    hold_speed(CRUISE_SPEED)
    gb, ge, gd = craft.goal()
    # TODO: Bug 2 modes "go" and "follow"
    turn(1.0 * mline_bearing())
    craft.plot("mline_offset", mline_offset())
```

### L4 reference `lesson04_bug2_ref.py`

```python
HIT_DIST = 90.0
FOLLOW_DIST = 50.0

def update(dt):
    hold_altitude(CRUISE_ALT)
    hold_speed(CRUISE_SPEED)
    gb, ge, gd = craft.goal()
    front = front_range()
    off = abs(mline_offset())
    if bug["mode"] == "go":
        if front < HIT_DIST:
            bug["mode"] = "follow"
            bug["hit_d"] = gd
            bug["away"] = False
            craft.log("hit")
        else:
            turn(1.0 * mline_bearing())
    if bug["mode"] == "follow":
        right = min(ray(60.0), ray(90.0))
        if front < HIT_DIST:
            turn(-MAX_TURN)
        elif right > 200.0:
            turn(0.5 * MAX_TURN)
        else:
            turn(0.004 * (right - FOLLOW_DIST))
        if off > 20.0:
            bug["away"] = True
        if bug["away"] and off < 5.0 and gd < bug["hit_d"] - 10.0:
            bug["mode"] = "go"
            craft.log("leave")
    craft.plot("mline_offset", mline_offset())
```

Hidden tests L4: `test_offset_sign`, `test_hit_stores_goal_distance`, `test_follow_turns_left_on_front`,
`test_leave_requires_progress`, `test_leave_requires_mline`.

### L5 starter `lesson05_potential.py`

```python
# Lesson 5: potential fields.
# Pseudocode from stage 2:
#   force = attraction toward goal
#   for each lidar hit closer than R0: add repulsion away from the hit
#   steer toward the force direction
#   if no progress for STUCK_TIME: add a sideways push to escape the local minimum

K_ATT = 1.0
K_REP = 0.0          # Tune this.
R0 = 0.0             # m, influence radius. Tune this.
STUCK_TIME = 15.0    # s
STUCK_GAIN = 20.0    # m of required progress in STUCK_TIME

pf = {"t_check": 0.0, "d_check": 1.0e9, "escape_until": -1.0}

def force():
    gb, ge, gd = craft.goal()
    fx = K_ATT * math.sin(gb)
    fy = K_ATT * math.cos(gb)
    # TODO: add repulsion from craft.lidar_scan() hits closer than R0
    return fx, fy

def update(dt):
    hold_altitude(CRUISE_ALT)
    hold_speed(CRUISE_SPEED)
    fx, fy = force()
    turn(0.8 * math.atan2(fx, fy))
    craft.plot("force_angle_deg", math.degrees(math.atan2(fx, fy)))
```

### L5 reference `lesson05_potential_ref.py`

```python
K_REP = 40000.0
R0 = 120.0

def force():
    gb, ge, gd = craft.goal()
    fx = K_ATT * math.sin(gb)
    fy = K_ATT * math.cos(gb)
    for hit in craft.lidar_scan():
        a, d = hit
        if d > 0.0 and d < R0:
            mag = K_REP * (1.0 / d - 1.0 / R0) / (d * d)
            r = math.radians(a)
            fx = fx - mag * math.sin(r)
            fy = fy - mag * math.cos(r)
    t = craft.time()
    if t - pf["t_check"] > STUCK_TIME:
        if pf["d_check"] - gd < STUCK_GAIN:
            pf["escape_until"] = t + 10.0
            craft.log("escape")
        pf["t_check"] = t
        pf["d_check"] = gd
    if t < pf["escape_until"]:
        fx = fx + 2.0 * K_ATT
    return fx, fy
```

Hidden tests L5: `test_attraction_only_points_at_goal`, `test_repulsion_zero_beyond_r0`,
`test_repulsion_grows_closer`, `test_symmetric_hits_cancel_sideways`, `test_escape_after_stall`.

## Course C5 (canyon)

| Field | Value |
|---|---|
| Extent | 700 x 2,600 m |
| Start | air start (0, 0, 80), 32 m/s, heading 0 |
| Centreline | (0, 0), (0, 400), (150, 800), (150, 1,200), (-100, 1,600), (-100, 2,000), (0, 2,400) |
| Canyon | `canyon-wall` both sides of the centreline at 70 m offset, 200 m tall, floor z = 0 |
| Corridor | box along the centreline, half width 70 m, floor 20 m, ceiling 180 m |
| Goal | finish gate at (0, 2,400, 80), inner radius 15 m, plane y = 2,400 |
| Wind | along canyon from 180 deg, 4 m/s, moderate gusts, seed 5505 |
| Time of day | `.golden` |

| Obstacle | Prop | Position | Size | Motion |
|---|---|---|---|---|
| H1 | `canyon-wall` pillar | (-30, 300) | radius 12, height 200 | static |
| H2 | `canyon-wall` pillar | (110, 750) | radius 12, height 200 | static |
| H3 | `canyon-wall` pillar | (180, 1,050) | radius 10, height 200 | static |
| H4 | `canyon-wall` pillar | (-40, 1,500) | radius 12, height 200 | static |
| H5 | `canyon-wall` pillar | (-130, 1,850) | radius 10, height 200 | static |
| H6 | `canyon-wall` pillar | (20, 2,250) | radius 12, height 200 | static |
| B1 | `obstacle-balloon` | (0, 600, 80) | radius 5 | x = 50 sin(2 pi t / 60) |
| B2 | `obstacle-balloon` | (150, 1,000, 90) | radius 5 | x = 150 + 50 sin(2 pi t / 60 + 1.5) |
| B3 | `obstacle-balloon` | (25, 1,400, 70) | radius 5 | x = 25 + 50 sin(2 pi t / 45) |
| B4 | `obstacle-balloon` | (-100, 1,800, 85) | radius 5 | x = -100 + 50 sin(2 pi t / 45 + 3.0) |

Pass: finish gate passed, no collision, no corridor exit. Par: energy 900 Wh, clearance 20 m.

### L6 starter `lesson06_vfh.py`

Aircraft helper block above this code, with `CRUISE_ALT = 80.0`, `CRUISE_SPEED = 32.0`.

```python
# Lesson 6: vector field histogram.
# Pseudocode from stage 2:
#   build a 36-sector polar histogram of obstacle density from the lidar scan
#   smooth it, mark sectors below THRESHOLD as free
#   pick the free sector closest to the goal direction, with free neighbours
#   steer toward that sector

THRESHOLD = 0.0       # Tune this.
MAX_RANGE = 120.0

def histogram():
    h = []
    for k in range(36):
        h.append(0.0)
    for hit in craft.lidar_scan():
        a, d = hit
        if d > 0.0 and d < MAX_RANGE:
            k = int((a + 180.0) / 10.0) % 36
            w = 1.0 - d / MAX_RANGE
            h[k] = h[k] + w * w
    return h

def smooth(h):
    s = []
    for k in range(36):
        s.append((h[(k + 35) % 36] + 2.0 * h[k] + h[(k + 1) % 36]) / 4.0)
    return s

def pick_sector(s, goal_deg):
    # TODO: return the steering angle in degrees, or None if no sector is free
    return goal_deg

def update(dt):
    hold_altitude(CRUISE_ALT)
    hold_speed(CRUISE_SPEED)
    gb, ge, gd = craft.goal()
    s = smooth(histogram())
    angle = pick_sector(s, math.degrees(gb))
    if angle is None:
        turn(MAX_TURN)
    else:
        turn(0.8 * math.radians(angle))
```

### L6 reference `lesson06_vfh_ref.py`

```python
THRESHOLD = 0.3

def pick_sector(s, goal_deg):
    best = None
    best_cost = 1.0e9
    for k in range(36):
        centre = k * 10.0 - 180.0 + 5.0
        if abs(centre) > 90.0:
            continue
        if s[k] < THRESHOLD and s[(k + 35) % 36] < THRESHOLD and s[(k + 1) % 36] < THRESHOLD:
            cost = abs(math.degrees(wrap(math.radians(centre - goal_deg))))
            if cost < best_cost:
                best_cost = cost
                best = centre
    return best
```

Hidden tests L6: `test_histogram_bins`, `test_smooth_wraps`, `test_pick_closest_to_goal`,
`test_pick_requires_wide_valley`, `test_none_when_blocked`.

### L8 starter `lesson08_astar.py`

Aircraft helper block above this code, with `CRUISE_ALT = 80.0`, `CRUISE_SPEED = 32.0`.

```python
# Lesson 8: A* on an occupancy grid built from lidar scans, replanned every second.
# Pseudocode from stage 2:
#   mark lidar hits (inflated) in the grid
#   every REPLAN s: A* from the craft cell toward the goal, stop at HORIZON m
#   follow the path with a lookahead point

CELL = 10.0
INFLATE = 0            # cells. Tune this.
HORIZON = 300.0        # m
EXPANSIONS_PER_TICK = 120
REPLAN = 1.0           # s
LOOKAHEAD = 40.0       # m
MEMORY = 20.0          # s a marked cell stays blocked
NEIGHBOURS = [(1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0),
              (1, 1, 1.414), (1, -1, 1.414), (-1, 1, 1.414), (-1, -1, 1.414)]

grid = {}
plan = {"open": [], "g": {}, "parent": {}, "start": 0, "done": True,
        "path": [], "t_last": -100.0, "gx": 0.0, "gy": 0.0, "sx": 0.0, "sy": 0.0}

def key(i, j):
    return (i + 5000) * 100000 + (j + 5000)

def cell_i(k):
    return k // 100000 - 5000

def cell_j(k):
    return k % 100000 - 5000

def centre(k):
    return (cell_i(k) + 0.5) * CELL, (cell_j(k) + 0.5) * CELL

def cell_of(x, y):
    return int(math.floor(x / CELL)), int(math.floor(y / CELL))

def heap_push(h, item):
    h.append(item)
    i = len(h) - 1
    while i > 0:
        p = (i - 1) // 2
        if h[p][0] <= h[i][0]:
            break
        t = h[p]
        h[p] = h[i]
        h[i] = t
        i = p

def heap_pop(h):
    top = h[0]
    last = h.pop()
    n = len(h)
    if n > 0:
        h[0] = last
        i = 0
        while True:
            c = 2 * i + 1
            if c >= n:
                break
            if c + 1 < n and h[c + 1][0] < h[c][0]:
                c = c + 1
            if h[i][0] <= h[c][0]:
                break
            t = h[i]
            h[i] = h[c]
            h[c] = t
            i = c
    return top

def blocked(k):
    if k in grid:
        return craft.time() - grid[k] < MEMORY
    return False

def mark_scan():
    p = craft.position()
    pitch, yaw, roll = craft.attitude()
    now = craft.time()
    for hit in craft.lidar_scan():
        a, d = hit
        if d > 0.0:
            ang = yaw + math.radians(a)
            ci, cj = cell_of(p[0] + d * math.sin(ang), p[1] + d * math.cos(ang))
            for di in range(-INFLATE, INFLATE + 1):
                for dj in range(-INFLATE, INFLATE + 1):
                    grid[key(ci + di, cj + dj)] = now

def heuristic(k):
    x, y = centre(k)
    return math.hypot(x - plan["gx"], y - plan["gy"])

def start_plan():
    p = craft.position()
    i, j = cell_of(p[0], p[1])
    s = key(i, j)
    plan["sx"] = p[0]
    plan["sy"] = p[1]
    plan["open"] = []
    plan["g"] = {s: 0.0}
    plan["parent"] = {s: -1}
    plan["start"] = s
    plan["done"] = False
    heap_push(plan["open"], (heuristic(s), s))

def extract(k):
    path = []
    while k != -1:
        path.insert(0, k)
        k = plan["parent"][k]
    return path

def step_plan():
    # TODO: run up to EXPANSIONS_PER_TICK A* expansions.
    # Finish when the popped cell is within CELL of the goal or HORIZON from the start:
    # set plan["path"] = extract(k) and plan["done"] = True.
    plan["done"] = True

def follow_path():
    p = craft.position()
    pitch, yaw, roll = craft.attitude()
    for k in plan["path"]:
        x, y = centre(k)
        if math.hypot(x - p[0], y - p[1]) > LOOKAHEAD:
            turn(0.8 * wrap(math.atan2(x - p[0], y - p[1]) - yaw))
            return
    gb, ge, gd = craft.goal()
    turn(0.8 * gb)

def setup():
    g = craft.goal_position()
    plan["gx"] = g[0]
    plan["gy"] = g[1]

def update(dt):
    hold_altitude(CRUISE_ALT)
    hold_speed(CRUISE_SPEED)
    if int(craft.time() / dt) % 5 == 0:
        mark_scan()
    if plan["done"] and craft.time() - plan["t_last"] >= REPLAN:
        start_plan()
        plan["t_last"] = craft.time()
    if not plan["done"]:
        step_plan()
    follow_path()
    craft.plot("path_cells", len(plan["path"]))
```

### L8 reference `lesson08_astar_ref.py`

```python
INFLATE = 2

def step_plan():
    n = 0
    while n < EXPANSIONS_PER_TICK and len(plan["open"]) > 0:
        item = heap_pop(plan["open"])
        f = item[0]
        k = item[1]
        gk = plan["g"][k]
        if f > gk + heuristic(k) + 0.001:
            continue
        n = n + 1
        x, y = centre(k)
        if heuristic(k) < CELL or math.hypot(x - plan["sx"], y - plan["sy"]) >= HORIZON:
            plan["path"] = extract(k)
            plan["done"] = True
            return
        i = cell_i(k)
        j = cell_j(k)
        for nb in NEIGHBOURS:
            nk = key(i + nb[0], j + nb[1])
            if blocked(nk):
                continue
            ng = gk + nb[2] * CELL
            if not (nk in plan["g"]) or ng < plan["g"][nk]:
                plan["g"][nk] = ng
                plan["parent"][nk] = k
                heap_push(plan["open"], (ng + heuristic(nk), nk))
    if len(plan["open"]) == 0:
        plan["done"] = True
```

Instruction cost: one expansion is about 600 VM instructions with 8 neighbours, so 120 expansions
fit the 100,000 per-tick budget (`05-coding-runtime.md`).

Hidden tests L8: `test_heap_order`, `test_astar_straight_line` (empty grid: path is a straight row),
`test_astar_around_block`, `test_inflate_marks_square`, `test_budget_per_tick` (no tick over
100,000 instructions on the recorded C5 frames).

## Course C6 (debris)

| Field | Value |
|---|---|
| Extent | 3,000 x 3,000 m, z to 10,500 m |
| Corridor | tube (0, 0, 0) to (0, 0, 10,500), radius 1,500 m |
| Goal | altitude 10,000 m inside the corridor (finish plane z = 10,000) |
| Wind | from 270 deg, 6 m/s at 10 m with shear to 20 m/s at 5 km, light gusts, seed 6006 |
| Time of day | `.morning` |
| Ground view | tabletop default; ground view shows the craft with distant LOD (`13-open-questions.md` item 4) |

Debris: 40 `debris-rock` instances (seeded variants from `boulder`, seed 6006). Listed position is
where the rock is when t = z / 100 (time a 100 m/s nominal ascent reaches its altitude). Position at
time t: `p(t) = p_listed + v * (t - z / 100)`. Spin about a seeded axis at the listed rate. RCS =
pi r².

| Id | x | y | z | r m | vx m/s | vy m/s | spin rad/s |
|---|---|---|---|---|---|---|---|
| D01 | 94 | 19 | 1,946 | 5.5 | 17.9 | -3.5 | 0.48 |
| D02 | 4 | -1 | 2,206 | 7.9 | 16.4 | 14.6 | 0.72 |
| D03 | -104 | -65 | 2,286 | 4.5 | 19.0 | 5.6 | 0.32 |
| D04 | 30 | -135 | 2,455 | 7.6 | -7.4 | -1.5 | 0.89 |
| D05 | -44 | -127 | 2,545 | 5.3 | 11.7 | -5.2 | 0.58 |
| D06 | -9 | 45 | 2,785 | 7.4 | 13.9 | -8.1 | 0.65 |
| D07 | 164 | 186 | 2,856 | 4.7 | -18.8 | -9.8 | 0.45 |
| D08 | 71 | -114 | 3,023 | 6.6 | 24.5 | -3.8 | 0.91 |
| D09 | -14 | -21 | 3,223 | 3.9 | 4.8 | 20.6 | 0.81 |
| D10 | 44 | -10 | 3,339 | 4.5 | -7.3 | -20.2 | 0.71 |
| D11 | 3 | -122 | 3,487 | 6.3 | -17.0 | 8.6 | 0.45 |
| D12 | -66 | 4 | 3,628 | 7.1 | -7.4 | 6.7 | 0.90 |
| D13 | 48 | 45 | 3,778 | 2.1 | -1.5 | -20.3 | 0.37 |
| D14 | 86 | 36 | 3,950 | 5.8 | 17.0 | 13.8 | 0.92 |
| D15 | 75 | -168 | 4,131 | 4.9 | 0.8 | 9.3 | 0.84 |
| D16 | 38 | -99 | 4,292 | 3.6 | -12.0 | -17.1 | 0.85 |
| D17 | 146 | -150 | 4,358 | 3.3 | 13.9 | -10.7 | 0.77 |
| D18 | -8 | 4 | 4,600 | 2.7 | -1.5 | 12.8 | 0.38 |
| D19 | 15 | -20 | 4,736 | 6.5 | 7.6 | 16.1 | 0.95 |
| D20 | -139 | -33 | 4,801 | 3.3 | 5.3 | 4.5 | 0.82 |
| D21 | -75 | -117 | 5,043 | 5.5 | 8.0 | -4.0 | 0.64 |
| D22 | 108 | 21 | 5,127 | 6.3 | -17.5 | -0.2 | 0.62 |
| D23 | 36 | 240 | 5,351 | 6.7 | 22.3 | 7.7 | 0.20 |
| D24 | 4 | 148 | 5,510 | 2.7 | -7.7 | -5.1 | 0.82 |
| D25 | -118 | -14 | 5,633 | 2.6 | -9.7 | 2.7 | 0.43 |
| D26 | 136 | 143 | 5,760 | 3.1 | 3.5 | -6.7 | 0.14 |
| D27 | 27 | -23 | 5,933 | 7.4 | -3.2 | -13.2 | 0.35 |
| D28 | 140 | 57 | 6,094 | 3.9 | 9.9 | 7.1 | 0.36 |
| D29 | -42 | 107 | 6,245 | 5.2 | 13.2 | 18.0 | 0.25 |
| D30 | 90 | 122 | 6,362 | 4.0 | -7.6 | 1.1 | 0.45 |
| D31 | 233 | 67 | 6,540 | 4.8 | 2.4 | 5.0 | 0.68 |
| D32 | -8 | -38 | 6,680 | 7.0 | 11.5 | -2.8 | 0.12 |
| D33 | 6 | -85 | 6,823 | 5.1 | 4.8 | 23.0 | 0.44 |
| D34 | -42 | -135 | 6,972 | 8.0 | -3.8 | 12.5 | 0.71 |
| D35 | 84 | 60 | 7,064 | 7.6 | 14.4 | -17.6 | 0.12 |
| D36 | -34 | 40 | 7,270 | 2.7 | -17.2 | -5.1 | 0.31 |
| D37 | -108 | -32 | 7,343 | 3.1 | -18.1 | -14.2 | 0.73 |
| D38 | 116 | 113 | 7,509 | 6.8 | -2.3 | 5.8 | 0.95 |
| D39 | -119 | 150 | 7,705 | 3.7 | 17.3 | 4.8 | 0.21 |
| D40 | -26 | 91 | 7,816 | 2.4 | 0.7 | -21.5 | 0.65 |

Pass: z = 10,000 m reached inside the corridor with no collision. Par: fuel 1,500 kg, clearance 40 m.

### Rocket helper block

Included at the top of the L7 and L9 starters.

```python
import craft
import math

G = 9.80665
MAX_TILT = math.radians(15.0)

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def tilt_to(east, north):
    # tilt the thrust to give a horizontal acceleration (east, north) in m/s^2
    pitch, yaw, roll = craft.attitude()
    mag = math.hypot(east, north)
    tilt = math.clamp(math.atan2(mag, G), 0.0, MAX_TILT)
    if mag > 0.5:
        craft.set_yaw(2.0 * wrap(math.atan2(east, north) - yaw))
    else:
        craft.set_yaw(0.0)
    craft.set_pitch(2.0 * ((math.pi / 2.0 - tilt) - pitch))
```

### L7 starter `lesson07_vo.py`

```python
# Lesson 7: velocity obstacles.
# Pseudocode from stage 2:
#   for each candidate horizontal velocity on a grid:
#     for each radar track: find the closest approach within HORIZON s
#     reject the candidate if any closest approach is under radius + MARGIN
#   pick the allowed candidate nearest the preferred velocity
#   tilt to reach it

HORIZON = 0.0      # s. Tune this.
MARGIN = 0.0       # m. Tune this.
STEP = 6.0         # m/s between candidates

def closest_approach(rp, u):
    # rp: obstacle position relative to craft; u: obstacle velocity relative to candidate
    # TODO: return the minimum distance over t in [0, HORIZON]
    return 1.0e9

def update(dt):
    craft.set_throttle(1.0)
    p = craft.position()
    v = craft.velocity()
    pref_x = -0.05 * p[0]
    pref_y = -0.05 * p[1]
    tracks = craft.radar_tracks()
    best = None
    best_cost = 1.0e9
    for ix in range(-4, 5):
        for iy in range(-4, 5):
            cx = ix * STEP
            cy = iy * STEP
            ok = True
            for tr in tracks:
                rp, rv, rad = tr
                u = (v[0] + rv[0] - cx, v[1] + rv[1] - cy, rv[2])
                if closest_approach(rp, u) < rad + MARGIN:
                    ok = False
                    break
            if ok:
                cost = math.hypot(cx - pref_x, cy - pref_y)
                if cost < best_cost:
                    best_cost = cost
                    best = (cx, cy)
    if best is None:
        best = (pref_x, pref_y)
        craft.log("no safe velocity")
    tilt_to(0.5 * (best[0] - v[0]), 0.5 * (best[1] - v[1]))
    craft.plot("tracks", len(tracks))
```

### L7 reference `lesson07_vo_ref.py`

```python
HORIZON = 8.0
MARGIN = 12.0

def closest_approach(rp, u):
    uu = u[0] * u[0] + u[1] * u[1] + u[2] * u[2]
    t = 0.0
    if uu > 1.0e-6:
        t = -(rp[0] * u[0] + rp[1] * u[1] + rp[2] * u[2]) / uu
        t = math.clamp(t, 0.0, HORIZON)
    dx = rp[0] + u[0] * t
    dy = rp[1] + u[1] * t
    dz = rp[2] + u[2] * t
    return math.sqrt(dx * dx + dy * dy + dz * dz)
```

Hidden tests L7: `test_cpa_head_on`, `test_cpa_receding_is_now`, `test_cpa_clamped_to_horizon`,
`test_candidate_rejected_in_cone`, `test_pick_nearest_preferred`.

### L9 starter `lesson09_rrt.py`

Rocket helper block above this code.

```python
# Lesson 9: RRT in 3D with path smoothing.
# Pseudocode from stage 2:
#   tree = [craft position]
#   repeat NODES times:
#     sample a point (goal-biased) in the box ahead
#     nearest = closest tree node; new = step STEP from nearest toward sample
#     if the edge is clear of predicted obstacles: add new
#   path = branch to the highest node; shortcut-smooth it; steer to the first waypoint

NODES = 60
STEP = 40.0          # m
GOAL_BIAS = 0.0      # Tune this.
MARGIN = 0.0         # m. Tune this.
CLIMB = 120.0        # m/s, used to time obstacle positions
AHEAD = 400.0        # m above the craft
REPLAN = 1.0         # s

rrt = {"path": [], "t_last": -100.0}

def predicted_clear(x, y, z, t, tracks, p, v):
    for tr in tracks:
        rp, rv, rad = tr
        ox = p[0] + rp[0] + (v[0] + rv[0]) * t
        oy = p[1] + rp[1] + (v[1] + rv[1]) * t
        oz = p[2] + rp[2] + (v[2] + rv[2]) * t
        if math.sqrt((x - ox) ** 2 + (y - oy) ** 2 + (z - oz) ** 2) < rad + MARGIN:
            return False
    return True

def edge_clear(a, b, tracks, p, v):
    n = int(math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]) / 10.0) + 1
    for s in range(n + 1):
        f = s / n
        x = a[0] + (b[0] - a[0]) * f
        y = a[1] + (b[1] - a[1]) * f
        z = a[2] + (b[2] - a[2]) * f
        if not predicted_clear(x, y, z, (z - p[2]) / CLIMB, tracks, p, v):
            return False
    return True

def build(p, v, tracks):
    # TODO: grow the tree, return the smoothed path as a list of (x, y, z)
    return []

def update(dt):
    craft.set_throttle(1.0)
    p = craft.position()
    v = craft.velocity()
    if craft.time() - rrt["t_last"] >= REPLAN:
        near = []
        for tr in craft.radar_tracks():
            if math.hypot(tr[0][0], tr[0][1], tr[0][2]) < 600.0:
                near.append(tr)
        path = build(p, v, near)
        if len(path) > 1:
            rrt["path"] = path
        rrt["t_last"] = craft.time()
    if len(rrt["path"]) > 1:
        w = rrt["path"][1]
        tilt_to(0.02 * (w[0] - p[0]) - 0.3 * v[0], 0.02 * (w[1] - p[1]) - 0.3 * v[1])
    else:
        tilt_to(-0.05 * p[0] - 0.3 * v[0], -0.05 * p[1] - 0.3 * v[1])
```

### L9 reference `lesson09_rrt_ref.py`

```python
GOAL_BIAS = 0.2
MARGIN = 15.0

def build(p, v, tracks):
    nodes = [(p[0], p[1], p[2], -1)]
    best = 0
    for it in range(NODES):
        if craft.random() < GOAL_BIAS:
            s = (0.0, 0.0, p[2] + AHEAD)
        else:
            s = ((craft.random() - 0.5) * 300.0, (craft.random() - 0.5) * 300.0,
                 p[2] + craft.random() * AHEAD)
        ni = 0
        nd = 1.0e9
        for i in range(len(nodes)):
            d = math.hypot(nodes[i][0] - s[0], nodes[i][1] - s[1], nodes[i][2] - s[2])
            if d < nd:
                nd = d
                ni = i
        a = nodes[ni]
        f = min(1.0, STEP / max(nd, 0.001))
        b = (a[0] + (s[0] - a[0]) * f, a[1] + (s[1] - a[1]) * f, a[2] + (s[2] - a[2]) * f)
        if edge_clear(a, b, tracks, p, v):
            nodes.append((b[0], b[1], b[2], ni))
            if b[2] > nodes[best][2]:
                best = len(nodes) - 1
    raw = []
    k = best
    while k != -1:
        raw.insert(0, (nodes[k][0], nodes[k][1], nodes[k][2]))
        k = nodes[k][3]
    path = [raw[0]]
    i = 0
    while i < len(raw) - 1:
        j = len(raw) - 1
        while j > i + 1 and not edge_clear(raw[i], raw[j], tracks, p, v):
            j = j - 1
        path.append(raw[j])
        i = j
    return path
```

Hidden tests L9: `test_tree_grows_from_start`, `test_edge_rejects_predicted_hit`,
`test_goal_bias_rate` (fixed seed, about 20% goal samples), `test_smoothing_keeps_clear_path`,
`test_budget_per_tick`.

## Course C7 (capstone generator)

`C7-<seed>` is generated from the seed on lesson start and stored in the `FlightRecord` so every
run of one attempt uses the same course. Seed = attempt start time in seconds modulo 2^31.

| Step | Rule |
|---|---|
| Family | seed even: field (C4 style); odd: canyon (C5 style) |
| Length | 1,500 to 2,500 m in 100 m steps |
| Field | 3 to 5 walls 120 to 240 m long, alternating sides of the M-line by 20 to 60 m, spaced 300 to 450 m; 6 to 10 pylons uniform in the corridor at least 60 m from walls |
| Canyon | centreline of 5 to 7 segments, each turn 15 to 30 deg; half width 60 to 80 m; 4 to 6 pillars radius 10 to 12 m at least 50 m apart; 3 to 5 balloons, amplitude 30 to 60 m, period 40 to 70 s |
| Wind | 0 to 6 m/s from a random direction, light gusts |
| Validity | The L6 reference solution must pass the generated course; otherwise the generator increments the seed and retries (maximum 20 tries, then falls back to C4) |

Pass: finish gate passed, no failure. Score: 50% energy vs par (par = 0.35 Wh per metre of
course length), 50% time vs par (par = course length / 32 m/s). Stars at 60, 80, 95.

### L10 starter `lesson10_capstone.py`

Aircraft helper block above this code. All sensors and API calls allowed on M7 are available.

```python
# Lesson 10: capstone. Pick any algorithm from lessons 3 to 9.
# Scored on energy and time. The course is new each attempt.

def setup():
    pass

def update(dt):
    hold_altitude(CRUISE_ALT)
    hold_speed(CRUISE_SPEED)
    gb, ge, gd = craft.goal()
    # TODO: your avoidance algorithm
    turn(0.8 * gb)
```

### L10 reference `lesson10_capstone_ref.py`

The L6 reference (`histogram`, `smooth`, `pick_sector` with THRESHOLD 0.3, `update`) with
`CRUISE_ALT = 80.0` and `CRUISE_SPEED = 32.0`. Hidden tests L10: none; grading is score only.

## Tuning note

Gains and thresholds in the reference solutions are starting values. Milestone M4 runs each reference
against its course in `FlightSim`; a reference must pass with 3 stars. When it does not, the gain in
the reference changes; course geometry and part constants change only through an edit to this file
and `14-parts-catalog.md`.

## M4 tuning record

Run against FlightSim with sensor noise on. Reference code as shipped lives in
`Curriculum/LessonCode.swift` and `LessonCode2.swift`; the code blocks above are the original drafts.

| Lesson | Course, craft | Result | Fuel or energy | Min clearance |
|---|---|---|---|---|
| L2 | C2, R-gates | pass | 382 kg | 9.4 m |
| L3 | C2B, R-walls | pass | 486 kg | 1.2 m |
| L4 | C4, A-field | pass | 151 Wh | 14.6 m |
| L5 | C4, A-field | pass | 134 Wh | 8.3 m |

Changes from the drafts:
- Rocket helpers (L2, L3): square-root braking altitude hold with engine cut below a 0.3 demand;
  `steer()` turns the velocity error into a heading error and tilt and leans back past vertical
  instead of turning the heading round (the simulator allows rocket pitch up to 135 deg).
- L3: lidar angles are taken from the flight path; the front fan is centred on the goal direction;
  avoiding slides sideways at SLIDE_SPEED 5 m/s; SAFE_DIST 35 m; CRUISE_SPEED 8 m/s. Par: fuel 490 kg,
  clearance 1 m.
- Aircraft helper: CRUISE_SPEED 25, MAX_TURN 0.39 (45 deg bank at 25 m/s; the simulator limits the
  heading rate to g / v). `hold_altitude` adds a 0.07 rad trim and gain 0.02.
- L4: HIT_DIST 110, FOLLOW_DIST 80; when the boundary ends the craft bends back toward the goal;
  a final mode aims at the finish gate inside 350 m.
- L5: K_ATT 2, K_REP 1.5e6, R0 120; only hits within 90 deg of the nose repel; four fine rays at
  ±5 and ±15 deg join the scan; at the saddle it turns 90 deg to the open side; attraction only
  inside 300 m of the gate.
