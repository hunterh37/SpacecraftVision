import Foundation

/// Starter and reference code for lessons 3 to 10 (specs/15, tuned in M4).
extension LessonCode {
    static let l3Starter = #"""
import craft
import math

# Rocket helpers from lesson 2.
G = 9.80665
CRUISE_SPEED = 8.0      # m/s horizontal
TILT_MAX = 0.35          # rad
K_V = 0.8                # 1/s, velocity error to acceleration
BRAKE = 1.5              # m/s2, planned braking when nearing the target height
VZ_MAX = 20.0            # m/s climb or sink limit

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

def track_offset_deg():
    # Angle from the nose heading to the flight path, deg; lidar angles are measured from the nose.
    v = craft.velocity()
    pitch, yaw, roll = craft.attitude()
    if math.hypot(v[0], v[1]) < 2.0:
        return 0.0
    return math.degrees(wrap(math.atan2(v[0], v[1]) - yaw))

def ray(angle_deg):
    # Range along the flight path plus angle_deg; 999 for no return.
    d = craft.lidar(angle_deg + track_offset_deg())
    if d < 0.0:
        return 999.0
    return d

def front_range(center_deg):
    # Closest return in a 20 deg fan around center_deg (measured from the flight path).
    return min(ray(center_deg - 10.0), ray(center_deg - 5.0), ray(center_deg), ray(center_deg + 5.0), ray(center_deg + 10.0))

def fly_toward(bearing, speed):
    err, tilt = steer(bearing, speed)
    hold_tilt(tilt)
    craft.set_yaw(math.clamp(1.2 * err, -0.5, 0.5))

# Lesson 3: Bug 0. Head to the goal; when an obstacle is close ahead, turn toward the
# more open side; resume as soon as the goal direction is clear.
# Pseudocode from stage 2:
#   loop:
#     if obstacle closer than SAFE_DIST ahead: turn away
#     else: head to goal

SAFE_DIST = 0.0       # m. Tune this.
TURN_DEG = 90.0       # deg off the goal direction while avoiding
SLIDE_SPEED = 5.0     # m/s along the obstacle
CRUISE_ALT = 40.0

bug = {"mode": "go", "side": 1.0}

def setup():
    craft.set_throttle(1.0)

def update(dt):
    bearing, elevation, dist = craft.next_gate()
    if dist < 0.0:
        bearing, elevation, dist = craft.goal()
    craft.set_throttle(throttle_for_altitude(CRUISE_ALT))
    # TODO: Bug 0 rule. Use front_range(), SAFE_DIST and bug["mode"].
    fly_toward(bearing, CRUISE_SPEED)
    craft.plot("front_range", front_range(math.degrees(bearing) - track_offset_deg()))
"""#
    static let l3Reference = #"""
import craft
import math

# Rocket helpers from lesson 2.
G = 9.80665
CRUISE_SPEED = 8.0      # m/s horizontal
TILT_MAX = 0.35          # rad
K_V = 0.8                # 1/s, velocity error to acceleration
BRAKE = 1.5              # m/s2, planned braking when nearing the target height
VZ_MAX = 20.0            # m/s climb or sink limit

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

def track_offset_deg():
    # Angle from the nose heading to the flight path, deg; lidar angles are measured from the nose.
    v = craft.velocity()
    pitch, yaw, roll = craft.attitude()
    if math.hypot(v[0], v[1]) < 2.0:
        return 0.0
    return math.degrees(wrap(math.atan2(v[0], v[1]) - yaw))

def ray(angle_deg):
    # Range along the flight path plus angle_deg; 999 for no return.
    d = craft.lidar(angle_deg + track_offset_deg())
    if d < 0.0:
        return 999.0
    return d

def front_range(center_deg):
    # Closest return in a 20 deg fan around center_deg (measured from the flight path).
    return min(ray(center_deg - 10.0), ray(center_deg - 5.0), ray(center_deg), ray(center_deg + 5.0), ray(center_deg + 10.0))

def fly_toward(bearing, speed):
    err, tilt = steer(bearing, speed)
    hold_tilt(tilt)
    craft.set_yaw(math.clamp(1.2 * err, -0.5, 0.5))

# Lesson 3: Bug 0. Head to the goal; when an obstacle is close ahead, turn toward the
# more open side; resume as soon as the goal direction is clear.

SAFE_DIST = 35.0      # m
TURN_DEG = 90.0       # deg off the goal direction while avoiding
SLIDE_SPEED = 5.0     # m/s along the obstacle
CRUISE_ALT = 40.0

bug = {"mode": "go", "side": 1.0}

def open_side():
    left = max(ray(-30.0), ray(-50.0), ray(-70.0))
    right = max(ray(30.0), ray(50.0), ray(70.0))
    if right >= left:
        return 1.0
    return -1.0

def setup():
    craft.set_throttle(1.0)

def update(dt):
    bearing, elevation, dist = craft.next_gate()
    if dist < 0.0:
        bearing, elevation, dist = craft.goal()
    craft.set_throttle(throttle_for_altitude(CRUISE_ALT))
    goal_deg = math.degrees(bearing) - track_offset_deg()
    front = front_range(goal_deg)
    if bug["mode"] == "go":
        if front < SAFE_DIST:
            bug["mode"] = "turn"
            bug["side"] = open_side()
            craft.log("obstacle")
        else:
            fly_toward(bearing, CRUISE_SPEED)
    if bug["mode"] == "turn":
        # Slide sideways: TURN_DEG off the goal direction toward the open side.
        fly_toward(wrap(bearing + bug["side"] * math.radians(TURN_DEG)), SLIDE_SPEED)
        if front > SAFE_DIST + 20.0:
            bug["mode"] = "go"
            craft.log("resume")
    craft.plot("front_range", front)
"""#
    static let l4Starter = #"""
import craft
import math

CRUISE_ALT = 120.0
CRUISE_SPEED = 25.0
TRIM = 0.07             # rad
MAX_TURN = 0.39          # rad/s heading rate, 45 deg bank at 25 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    # TRIM is the pitch that holds level flight at cruise speed.
    want = math.clamp(TRIM + 0.02 * (target - craft.altitude()) - 0.05 * vz, -0.2, 0.25)
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
"""#
    static let l4Reference = #"""
import craft
import math

CRUISE_ALT = 120.0
CRUISE_SPEED = 25.0
TRIM = 0.07             # rad
MAX_TURN = 0.39          # rad/s heading rate, 45 deg bank at 25 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    # TRIM is the pitch that holds level flight at cruise speed.
    want = math.clamp(TRIM + 0.02 * (target - craft.altitude()) - 0.05 * vz, -0.2, 0.25)
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

# Lesson 4: Bug 2.
# Pseudocode from stage 2:
#   go: follow the M-line toward the goal
#   if obstacle ahead closer than HIT_DIST: remember goal distance, switch to follow
#   follow: keep the obstacle on the right at FOLLOW_DIST
#   leave when back on the M-line and closer to the goal than at the hit point

HIT_DIST = 110.0
FOLLOW_DIST = 80.0
FINAL_DIST = 350.0    # m: aim straight at the finish gate
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
    front = front_range()
    off = abs(mline_offset())
    if bug["mode"] != "final" and gd < FINAL_DIST and front > 0.5 * HIT_DIST:
        bug["mode"] = "final"
        craft.log("final")
    if bug["mode"] == "final":
        if front < 40.0:
            turn(-MAX_TURN)
        else:
            turn(2.5 * gb)
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
            # Boundary ended on the right: bend back toward the goal.
            turn(0.8 * gb)
        else:
            turn(0.004 * (right - FOLLOW_DIST))
        if off > 20.0:
            bug["away"] = True
        if bug["away"] and off < 5.0 and gd < bug["hit_d"] - 10.0:
            bug["mode"] = "go"
            craft.log("leave")
    craft.plot("mline_offset", mline_offset())
"""#
    static let l5Starter = #"""
import craft
import math

CRUISE_ALT = 120.0
CRUISE_SPEED = 25.0
TRIM = 0.07             # rad
MAX_TURN = 0.39          # rad/s heading rate, 45 deg bank at 25 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    # TRIM is the pitch that holds level flight at cruise speed.
    want = math.clamp(TRIM + 0.02 * (target - craft.altitude()) - 0.05 * vz, -0.2, 0.25)
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
"""#
    static let l5Reference = #"""
import craft
import math

CRUISE_ALT = 120.0
CRUISE_SPEED = 25.0
TRIM = 0.07             # rad
MAX_TURN = 0.39          # rad/s heading rate, 45 deg bank at 25 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    # TRIM is the pitch that holds level flight at cruise speed.
    want = math.clamp(TRIM + 0.02 * (target - craft.altitude()) - 0.05 * vz, -0.2, 0.25)
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

# Lesson 5: potential fields.
# Pseudocode from stage 2:
#   force = attraction toward goal
#   for each lidar hit closer than R0: add repulsion away from the hit
#   steer toward the force direction
#   if no progress for STUCK_TIME: add a sideways push to escape the local minimum

K_ATT = 2.0
K_REP = 1500000.0
R0 = 120.0
FOV = 90.0           # deg: only hits ahead of the wing line push
GAIN = 0.8           # heading rate per rad of force angle
FINAL_DIST = 300.0   # m
STUCK_TIME = 15.0    # s
STUCK_GAIN = 20.0    # m of required progress in STUCK_TIME

pf = {"t_check": 0.0, "d_check": 1.0e9, "escape_until": -1.0}

def force():
    gb, ge, gd = craft.goal()
    fx = K_ATT * math.sin(gb)
    fy = K_ATT * math.cos(gb)
    hits = craft.lidar_scan()
    # The scan's 10 deg spacing misses a 3 m pylon beyond 20 m: add a fine fan ahead.
    for a in [-15.0, -5.0, 5.0, 15.0]:
        hits.append((a, craft.lidar(a)))
    for hit in hits:
        a, d = hit
        if d > 0.0 and d < R0 and abs(a) <= FOV:
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
def update(dt):
    hold_altitude(CRUISE_ALT)
    hold_speed(CRUISE_SPEED)
    fx, fy = force()
    ang = math.atan2(fx, fy)
    if abs(ang) > math.radians(100.0):
        # Force points back at the obstacle face: the field's saddle. Turn toward the more open side.
        right = ray(30.0) + ray(60.0) + ray(90.0)
        left = ray(-30.0) + ray(-60.0) + ray(-90.0)
        if right >= left:
            ang = math.radians(90.0)
        else:
            ang = -math.radians(90.0)
    gb, ge, gd = craft.goal()
    if gd < FINAL_DIST and front_range() > 40.0:
        # Close to the finish gate its own ring would repel: attraction only.
        turn(2.5 * gb)
    else:
        turn(GAIN * ang)
    craft.plot("force_angle_deg", math.degrees(math.atan2(fx, fy)))
"""#
    static let l7Starter = #"""
import craft
import math

G = 9.80665
MAX_TILT = math.radians(15.0)
CLIMB_RATE = 100.0   # m/s, the nominal ascent the debris table is timed for

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def hold_climb(rate):
    # Solids light on the first nonzero throttle and cannot stop; the liquid engine trims the rest.
    vz = craft.velocity()[2]
    if vz > rate + 3.0:
        craft.set_throttle(0.0)
    else:
        craft.set_throttle(math.clamp(0.4 + 0.1 * (rate - vz), 0.4, 1.0))

def tilt_to(east, north):
    # tilt the thrust to give a horizontal acceleration (east, north) in m/s^2;
    # leans back past vertical instead of turning the heading around
    pitch, yaw, roll = craft.attitude()
    mag = math.hypot(east, north)
    if mag < 0.3:
        craft.set_yaw(0.0)
        craft.set_pitch(2.0 * (math.pi / 2.0 - pitch))
        return
    err = wrap(math.atan2(east, north) - yaw)
    sign = 1.0
    if abs(err) > math.pi / 2.0:
        err = wrap(err + math.pi)
        sign = -1.0
    tilt = sign * math.clamp(math.atan2(mag, G), 0.0, MAX_TILT) * math.cos(err)
    craft.set_yaw(math.clamp(2.0 * err, -0.5, 0.5))
    craft.set_pitch(2.0 * ((math.pi / 2.0 - tilt) - pitch))

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
RANGE = 600.0      # m, tracks farther than this are ignored

def closest_approach(rp, u):
    # rp: obstacle position relative to craft; u: obstacle velocity relative to candidate
    # TODO: return the minimum distance over t in [0, HORIZON]
    return 1.0e9

def update(dt):
    hold_climb(CLIMB_RATE)
    p = craft.position()
    v = craft.velocity()
    pref_x = -0.05 * p[0]
    pref_y = -0.05 * p[1]
    tracks = []
    for tr in craft.radar_tracks():
        if math.hypot(tr[0][0], tr[0][1], tr[0][2]) < RANGE:
            tracks.append(tr)
    best = None
    best_cost = 1.0e9
    for ix in range(-3, 4):
        for iy in range(-3, 4):
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
"""#
    static let l7Reference = #"""
import craft
import math

G = 9.80665
MAX_TILT = math.radians(15.0)
CLIMB_RATE = 100.0   # m/s, the nominal ascent the debris table is timed for

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def hold_climb(rate):
    # Solids light on the first nonzero throttle and cannot stop; the liquid engine trims the rest.
    vz = craft.velocity()[2]
    if vz > rate + 3.0:
        craft.set_throttle(0.0)
    else:
        craft.set_throttle(math.clamp(0.4 + 0.1 * (rate - vz), 0.4, 1.0))

def tilt_to(east, north):
    # tilt the thrust to give a horizontal acceleration (east, north) in m/s^2;
    # leans back past vertical instead of turning the heading around
    pitch, yaw, roll = craft.attitude()
    mag = math.hypot(east, north)
    if mag < 0.3:
        craft.set_yaw(0.0)
        craft.set_pitch(2.0 * (math.pi / 2.0 - pitch))
        return
    err = wrap(math.atan2(east, north) - yaw)
    sign = 1.0
    if abs(err) > math.pi / 2.0:
        err = wrap(err + math.pi)
        sign = -1.0
    tilt = sign * math.clamp(math.atan2(mag, G), 0.0, MAX_TILT) * math.cos(err)
    craft.set_yaw(math.clamp(2.0 * err, -0.5, 0.5))
    craft.set_pitch(2.0 * ((math.pi / 2.0 - tilt) - pitch))

# Lesson 7: velocity obstacles.
# Pseudocode from stage 2:
#   for each candidate horizontal velocity on a grid:
#     for each radar track: find the closest approach within HORIZON s
#     reject the candidate if any closest approach is under radius + MARGIN
#   pick the allowed candidate nearest the preferred velocity
#   tilt to reach it

HORIZON = 8.0
MARGIN = 20.0
STEP = 6.0         # m/s between candidates
RANGE = 600.0      # m, tracks farther than this are ignored

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
def update(dt):
    hold_climb(CLIMB_RATE)
    p = craft.position()
    v = craft.velocity()
    pref_x = -0.05 * p[0]
    pref_y = -0.05 * p[1]
    tracks = []
    for tr in craft.radar_tracks():
        if math.hypot(tr[0][0], tr[0][1], tr[0][2]) < RANGE:
            tracks.append(tr)
    best = None
    best_cost = 1.0e9
    for ix in range(-3, 4):
        for iy in range(-3, 4):
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
"""#
    static let l9Starter = #"""
import craft
import math

G = 9.80665
MAX_TILT = math.radians(15.0)
CLIMB_RATE = 100.0   # m/s, the nominal ascent the debris table is timed for

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def hold_climb(rate):
    # Solids light on the first nonzero throttle and cannot stop; the liquid engine trims the rest.
    vz = craft.velocity()[2]
    if vz > rate + 3.0:
        craft.set_throttle(0.0)
    else:
        craft.set_throttle(math.clamp(0.4 + 0.1 * (rate - vz), 0.4, 1.0))

def tilt_to(east, north):
    # tilt the thrust to give a horizontal acceleration (east, north) in m/s^2;
    # leans back past vertical instead of turning the heading around
    pitch, yaw, roll = craft.attitude()
    mag = math.hypot(east, north)
    if mag < 0.3:
        craft.set_yaw(0.0)
        craft.set_pitch(2.0 * (math.pi / 2.0 - pitch))
        return
    err = wrap(math.atan2(east, north) - yaw)
    sign = 1.0
    if abs(err) > math.pi / 2.0:
        err = wrap(err + math.pi)
        sign = -1.0
    tilt = sign * math.clamp(math.atan2(mag, G), 0.0, MAX_TILT) * math.cos(err)
    craft.set_yaw(math.clamp(2.0 * err, -0.5, 0.5))
    craft.set_pitch(2.0 * ((math.pi / 2.0 - tilt) - pitch))

# Lesson 9: RRT in 3D with path smoothing.
# Pseudocode from stage 2:
#   tree = [craft position]
#   repeat NODES times:
#     sample a point (goal-biased) in the box ahead
#     nearest = closest tree node; new = step STEP from nearest toward sample
#     if the edge is clear of predicted obstacles: add new
#   path = branch to the highest node; shortcut-smooth it; steer to the first waypoint

NODES = 30
STEP = 40.0          # m
GOAL_BIAS = 0.0      # Tune this.
MARGIN = 0.0         # m. Tune this.
CLIMB = 100.0        # m/s, used to time obstacle positions
AHEAD = 900.0        # m above the craft
REPLAN = 1.0         # s
SMOOTH_SPAN = 3      # nodes a shortcut may skip, keeps the tick in budget
LEAD = 150.0         # m, steer to the path point this far above the craft
KP_PATH = 0.1
KD_PATH = 0.6

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
    n = int(math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]) / 40.0) + 1
    for s in range(n + 1):
        f = s / n
        x = a[0] + (b[0] - a[0]) * f
        y = a[1] + (b[1] - a[1]) * f
        z = a[2] + (b[2] - a[2]) * f
        if not predicted_clear(x, y, z, (z - p[2]) / max(v[2], CLIMB * 0.5), tracks, p, v):
            return False
    return True

def build(p, v, tracks):
    # TODO: grow the tree, return the smoothed path as a list of (x, y, z)
    return []

def path_point(path, z):
    # Point on the path at altitude z (end points beyond its ends).
    if z <= path[0][2]:
        return path[0]
    for i in range(len(path) - 1):
        a = path[i]
        b = path[i + 1]
        if z <= b[2]:
            f = (z - a[2]) / max(b[2] - a[2], 0.001)
            return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, z)
    return path[len(path) - 1]

def update(dt):
    hold_climb(CLIMB_RATE)
    p = craft.position()
    v = craft.velocity()
    if craft.time() - rrt["t_last"] >= REPLAN:
        rrt["t_last"] = craft.time()
        near = []
        for tr in craft.radar_tracks():
            # rocks keep their altitude: plan only around those in the band ahead
            if tr[0][2] > -20.0 and tr[0][2] < AHEAD + 50.0 and math.hypot(tr[0][0], tr[0][1]) < 400.0:
                near.append(tr)
        path = build(p, v, near)
        if len(path) > 1:
            rrt["path"] = path
    if len(rrt["path"]) > 1:
        w = path_point(rrt["path"], p[2] + LEAD)
        tilt_to(KP_PATH * (w[0] - p[0]) - KD_PATH * v[0], KP_PATH * (w[1] - p[1]) - KD_PATH * v[1])
    else:
        tilt_to(-0.05 * p[0] - 0.3 * v[0], -0.05 * p[1] - 0.3 * v[1])
"""#
    static let l9Reference = #"""
import craft
import math

G = 9.80665
MAX_TILT = math.radians(15.0)
CLIMB_RATE = 100.0   # m/s, the nominal ascent the debris table is timed for

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

def hold_climb(rate):
    # Solids light on the first nonzero throttle and cannot stop; the liquid engine trims the rest.
    vz = craft.velocity()[2]
    if vz > rate + 3.0:
        craft.set_throttle(0.0)
    else:
        craft.set_throttle(math.clamp(0.4 + 0.1 * (rate - vz), 0.4, 1.0))

def tilt_to(east, north):
    # tilt the thrust to give a horizontal acceleration (east, north) in m/s^2;
    # leans back past vertical instead of turning the heading around
    pitch, yaw, roll = craft.attitude()
    mag = math.hypot(east, north)
    if mag < 0.3:
        craft.set_yaw(0.0)
        craft.set_pitch(2.0 * (math.pi / 2.0 - pitch))
        return
    err = wrap(math.atan2(east, north) - yaw)
    sign = 1.0
    if abs(err) > math.pi / 2.0:
        err = wrap(err + math.pi)
        sign = -1.0
    tilt = sign * math.clamp(math.atan2(mag, G), 0.0, MAX_TILT) * math.cos(err)
    craft.set_yaw(math.clamp(2.0 * err, -0.5, 0.5))
    craft.set_pitch(2.0 * ((math.pi / 2.0 - tilt) - pitch))

# Lesson 9: RRT in 3D with path smoothing.
# Pseudocode from stage 2:
#   tree = [craft position]
#   repeat NODES times:
#     sample a point (goal-biased) in the box ahead
#     nearest = closest tree node; new = step STEP from nearest toward sample
#     if the edge is clear of predicted obstacles: add new
#   path = branch to the highest node; shortcut-smooth it; steer to the first waypoint

NODES = 30
STEP = 40.0          # m
GOAL_BIAS = 0.2
MARGIN = 20.0
CLIMB = 100.0        # m/s, used to time obstacle positions
AHEAD = 900.0        # m above the craft
REPLAN = 1.0         # s
SMOOTH_SPAN = 3      # nodes a shortcut may skip, keeps the tick in budget
LEAD = 150.0         # m, steer to the path point this far above the craft
KP_PATH = 0.1
KD_PATH = 0.6

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
    n = int(math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]) / 40.0) + 1
    for s in range(n + 1):
        f = s / n
        x = a[0] + (b[0] - a[0]) * f
        y = a[1] + (b[1] - a[1]) * f
        z = a[2] + (b[2] - a[2]) * f
        if not predicted_clear(x, y, z, (z - p[2]) / max(v[2], CLIMB * 0.5), tracks, p, v):
            return False
    return True

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
        j = min(len(raw) - 1, i + SMOOTH_SPAN)
        while j > i + 1 and not edge_clear(raw[i], raw[j], tracks, p, v):
            j = j - 1
        path.append(raw[j])
        i = j
    return path
def path_point(path, z):
    # Point on the path at altitude z (end points beyond its ends).
    if z <= path[0][2]:
        return path[0]
    for i in range(len(path) - 1):
        a = path[i]
        b = path[i + 1]
        if z <= b[2]:
            f = (z - a[2]) / max(b[2] - a[2], 0.001)
            return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, z)
    return path[len(path) - 1]

def update(dt):
    hold_climb(CLIMB_RATE)
    p = craft.position()
    v = craft.velocity()
    if craft.time() - rrt["t_last"] >= REPLAN:
        rrt["t_last"] = craft.time()
        near = []
        for tr in craft.radar_tracks():
            # rocks keep their altitude: plan only around those in the band ahead
            if tr[0][2] > -20.0 and tr[0][2] < AHEAD + 50.0 and math.hypot(tr[0][0], tr[0][1]) < 400.0:
                near.append(tr)
        path = build(p, v, near)
        if len(path) > 1:
            rrt["path"] = path
    if len(rrt["path"]) > 1:
        w = path_point(rrt["path"], p[2] + LEAD)
        tilt_to(KP_PATH * (w[0] - p[0]) - KD_PATH * v[0], KP_PATH * (w[1] - p[1]) - KD_PATH * v[1])
    else:
        tilt_to(-0.05 * p[0] - 0.3 * v[0], -0.05 * p[1] - 0.3 * v[1])
"""#
    static let l6Starter = #"""
import craft
import math

CRUISE_ALT = 80.0
CRUISE_SPEED = 30.0
ALPHA_MAX = 0.17         # rad, 10 deg below the 15 deg stall
MAX_TURN = 0.33          # rad/s heading rate, 45 deg bank at 30 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

trim = {"i": 0.05}

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    err = target - craft.altitude()
    # Integral trim removes the steady height error (the wing needs a few degrees of nose-up).
    trim["i"] = math.clamp(trim["i"] + 0.0004 * err, -0.05, 0.2)
    want = math.clamp(trim["i"] + 0.03 * err - 0.1 * vz, -0.2, 0.3)
    # Keep the wing below stall: nose at most ALPHA_MAX above the flight path.
    v = craft.velocity()
    gamma = math.atan2(v[2], math.hypot(v[0], v[1]))
    want = min(want, gamma + ALPHA_MAX)
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

# Lesson 6: vector field histogram.
# Pseudocode from stage 2:
#   build a 36-sector polar histogram of obstacle density from the lidar scan
#   smooth it, mark sectors below THRESHOLD as free
#   pick the free sector closest to the goal direction, with free neighbours
#   steer toward that sector

THRESHOLD = 0.0       # Tune this.
VALLEY = 1            # free neighbours needed each side
W_GOAL = 1.0
WIDE = 3              # sectors kept between the path and a valley edge
W_HEADING = 0.5
TURN_GAIN = 1.5
MAX_RANGE = 120.0
R_SAFE = 10.0         # m, craft half span plus margin

def histogram():
    h = []
    for k in range(36):
        h.append(0.0)
    for hit in craft.lidar_scan():
        a, d = hit
        if d > 0.0 and d < MAX_RANGE:
            w = 1.0 - d / MAX_RANGE
            # Enlarge each hit by the safety radius seen from the craft (VFH+).
            spread = math.degrees(math.asin(min(1.0, R_SAFE / d)))
            k0 = int(math.floor((a - spread + 180.0) / 10.0))
            k1 = int(math.floor((a + spread + 180.0) / 10.0))
            for k in range(k0, k1 + 1):
                h[(k + 36) % 36] = h[(k + 36) % 36] + w * w
    return h

def smooth(h):
    s = []
    for k in range(36):
        s.append((h[(k + 35) % 36] + 2.0 * h[k] + h[(k + 1) % 36]) / 4.0)
    return s

def pick_sector(s, goal_deg):
    # TODO: find runs of sectors below THRESHOLD within 90 deg of the nose (valleys),
    # pick a steering angle in the valley closest to the goal; return None if none is free.
    return goal_deg

def least_dense(s):
    # Fallback when nothing is free: the emptiest sector ahead.
    best = 0.0
    low = 1.0e9
    for k in range(36):
        centre = k * 10.0 - 180.0 + 5.0
        if abs(centre) <= 90.0 and s[k] < low:
            low = s[k]
            best = centre
    return best

def update(dt):
    hold_altitude(CRUISE_ALT)
    hold_speed(CRUISE_SPEED)
    gb, ge, gd = craft.goal()
    s = smooth(histogram())
    angle = pick_sector(s, math.degrees(gb))
    if angle is None:
        angle = least_dense(s)
        turn(TURN_GAIN * math.radians(angle))
    else:
        turn(TURN_GAIN * math.radians(angle))
    if angle is not None:
        craft.plot("heading_deg", angle)
"""#
    static let l6Reference = #"""
import craft
import math

CRUISE_ALT = 80.0
CRUISE_SPEED = 30.0
ALPHA_MAX = 0.17         # rad, 10 deg below the 15 deg stall
MAX_TURN = 0.33          # rad/s heading rate, 45 deg bank at 30 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

trim = {"i": 0.05}

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    err = target - craft.altitude()
    # Integral trim removes the steady height error (the wing needs a few degrees of nose-up).
    trim["i"] = math.clamp(trim["i"] + 0.0004 * err, -0.05, 0.2)
    want = math.clamp(trim["i"] + 0.03 * err - 0.1 * vz, -0.2, 0.3)
    # Keep the wing below stall: nose at most ALPHA_MAX above the flight path.
    v = craft.velocity()
    gamma = math.atan2(v[2], math.hypot(v[0], v[1]))
    want = min(want, gamma + ALPHA_MAX)
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

# Lesson 6: vector field histogram.
# Pseudocode from stage 2:
#   build a 36-sector polar histogram of obstacle density from the lidar scan
#   smooth it, mark sectors below THRESHOLD as free
#   pick the free sector closest to the goal direction, with free neighbours
#   steer toward that sector

THRESHOLD = 0.8
VALLEY = 1            # free neighbours needed each side
W_GOAL = 1.0
WIDE = 3              # sectors kept between the path and a valley edge
W_HEADING = 0.5
W_PREV = 1.0

vfh = {"prev": -999.0, "prev_abs": -999.0}
TURN_GAIN = 1.5
MAX_RANGE = 120.0
R_SAFE = 10.0         # m, craft half span plus margin

def histogram():
    h = []
    for k in range(36):
        h.append(0.0)
    for hit in craft.lidar_scan():
        a, d = hit
        if d > 0.0 and d < MAX_RANGE:
            w = 1.0 - d / MAX_RANGE
            # Enlarge each hit by the safety radius seen from the craft (VFH+).
            spread = math.degrees(math.asin(min(1.0, R_SAFE / d)))
            k0 = int(math.floor((a - spread + 180.0) / 10.0))
            k1 = int(math.floor((a + spread + 180.0) / 10.0))
            for k in range(k0, k1 + 1):
                h[(k + 36) % 36] = h[(k + 36) % 36] + w * w
    return h

def smooth(h):
    s = []
    for k in range(36):
        s.append((h[(k + 35) % 36] + 2.0 * h[k] + h[(k + 1) % 36]) / 4.0)
    return s

def pick_sector(s, goal_deg):
    # Valleys: runs of free sectors within 90 deg of the nose. In a wide valley aim WIDE sectors
    # in from the edge nearest the goal (or at the goal if it lies inside); in a narrow one, its middle.
    best = None
    best_cost = 1.0e9
    k = 9
    while k <= 26:
        if s[k] >= THRESHOLD:
            k = k + 1
            continue
        start = k
        while k <= 26 and s[k] < THRESHOLD:
            k = k + 1
        stop = k - 1
        lo = start * 10.0 - 180.0 + 5.0
        hi = stop * 10.0 - 180.0 + 5.0
        if stop - start + 1 < 2 * VALLEY + 1:
            continue
        if stop - start + 1 >= 2 * WIDE:
            a_lo = lo + (WIDE - 1) * 10.0
            a_hi = hi - (WIDE - 1) * 10.0
            target = min(max(goal_deg, a_lo), a_hi)
        else:
            target = (lo + hi) / 2.0
        cost = W_GOAL * abs(target - goal_deg) + W_HEADING * abs(target)
        if vfh["prev"] > -900.0:
            # Hysteresis: stay with the valley picked last tick instead of flipping sides.
            cost = cost + W_PREV * abs(math.degrees(wrap(math.radians(target - vfh["prev"]))))
        if cost < best_cost:
            best_cost = cost
            best = target
    return best

def least_dense(s):
    # Fallback when nothing is free: the emptiest sector ahead.
    best = 0.0
    low = 1.0e9
    for k in range(36):
        centre = k * 10.0 - 180.0 + 5.0
        if abs(centre) <= 90.0 and s[k] < low:
            low = s[k]
            best = centre
    return best

def update(dt):
    hold_altitude(CRUISE_ALT)
    hold_speed(CRUISE_SPEED)
    gb, ge, gd = craft.goal()
    s = smooth(histogram())
    pitch, yaw, roll = craft.attitude()
    if vfh["prev_abs"] > -900.0:
        vfh["prev"] = math.degrees(wrap(math.radians(vfh["prev_abs"]) - yaw))
    angle = pick_sector(s, math.degrees(gb))
    if angle is not None:
        vfh["prev_abs"] = math.degrees(yaw) + angle
    if angle is None:
        angle = least_dense(s)
        turn(TURN_GAIN * math.radians(angle))
    else:
        turn(TURN_GAIN * math.radians(angle))
    craft.plot("heading_deg", angle)
"""#
    static let l8Starter = #"""
import craft
import math

CRUISE_ALT = 80.0
CRUISE_SPEED = 30.0
ALPHA_MAX = 0.17         # rad, 10 deg below the 15 deg stall
MAX_TURN = 0.33          # rad/s heading rate, 45 deg bank at 30 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

trim = {"i": 0.05}

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    err = target - craft.altitude()
    # Integral trim removes the steady height error (the wing needs a few degrees of nose-up).
    trim["i"] = math.clamp(trim["i"] + 0.0004 * err, -0.05, 0.2)
    want = math.clamp(trim["i"] + 0.03 * err - 0.1 * vz, -0.2, 0.3)
    # Keep the wing below stall: nose at most ALPHA_MAX above the flight path.
    v = craft.velocity()
    gamma = math.atan2(v[2], math.hypot(v[0], v[1]))
    want = min(want, gamma + ALPHA_MAX)
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
"""#
    static let l8Reference = #"""
import craft
import math

CRUISE_ALT = 80.0
CRUISE_SPEED = 30.0
ALPHA_MAX = 0.17         # rad, 10 deg below the 15 deg stall
MAX_TURN = 0.33          # rad/s heading rate, 45 deg bank at 30 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

trim = {"i": 0.05}

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    err = target - craft.altitude()
    # Integral trim removes the steady height error (the wing needs a few degrees of nose-up).
    trim["i"] = math.clamp(trim["i"] + 0.0004 * err, -0.05, 0.2)
    want = math.clamp(trim["i"] + 0.03 * err - 0.1 * vz, -0.2, 0.3)
    # Keep the wing below stall: nose at most ALPHA_MAX above the flight path.
    v = craft.velocity()
    gamma = math.atan2(v[2], math.hypot(v[0], v[1]))
    want = min(want, gamma + ALPHA_MAX)
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

# Lesson 8: A* on an occupancy grid built from lidar scans, replanned every second.
# Pseudocode from stage 2:
#   mark lidar hits (inflated) in the grid
#   every REPLAN s: A* from the craft cell toward the goal, stop at HORIZON m
#   follow the path with a lookahead point

CELL = 10.0
INFLATE = 2
MARGIN = 1             # cells of soft margin around blocked cells
NEAR_COST = 3.0        # extra cost per cell inside the margin
HORIZON = 250.0        # m
EXPANSIONS_PER_TICK = 120
REPLAN = 0.5           # s
LOOKAHEAD = 30.0       # m
GUARD = 60.0           # m, local safety check on the planned heading
TURN_GAIN = 1.2
MEMORY = 20.0          # s a marked cell stays blocked
NEIGHBOURS = [(1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0),
              (1, 1, 1.414), (1, -1, 1.414), (-1, 1, 1.414), (-1, -1, 1.414)]

grid = {}
near = {}
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
            for di in range(-INFLATE - MARGIN, INFLATE + MARGIN + 1):
                for dj in range(-INFLATE - MARGIN, INFLATE + MARGIN + 1):
                    near[key(ci + di, cj + dj)] = now

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
            if nk in near and craft.time() - near[nk] < MEMORY:
                ng = ng + NEAR_COST * CELL
            if not (nk in plan["g"]) or ng < plan["g"][nk]:
                plan["g"][nk] = ng
                plan["parent"][nk] = k
                heap_push(plan["open"], (ng + heuristic(nk), nk))
    if len(plan["open"]) == 0:
        plan["done"] = True
def clear_heading(want):
    # Local check on the planned heading (rad, relative to the nose): if the lidar sees
    # something within GUARD m in a 30 deg fan around it, take the nearest clear ray instead.
    scan = craft.lidar_scan()
    best = want
    best_cost = 1.0e9
    for hit in scan:
        a = math.radians(hit[0])
        if abs(a) > math.pi / 2.0:
            continue
        ok = True
        for other in scan:
            if other[1] > 0.0 and other[1] < GUARD and abs(wrap(math.radians(other[0]) - a)) <= math.radians(15.0):
                ok = False
        if ok:
            cost = abs(wrap(a - want))
            if cost < best_cost:
                best_cost = cost
                best = a
    return best

def follow_path():
    p = craft.position()
    pitch, yaw, roll = craft.attitude()
    want = None
    for k in plan["path"]:
        x, y = centre(k)
        if math.hypot(x - p[0], y - p[1]) > LOOKAHEAD:
            want = wrap(math.atan2(x - p[0], y - p[1]) - yaw)
            break
    if want is None:
        gb, ge, gd = craft.goal()
        want = gb
    turn(TURN_GAIN * clear_heading(want))

def setup():
    g = craft.goal_position()
    plan["gx"] = g[0]
    plan["gy"] = g[1]

def update(dt):
    hold_altitude(CRUISE_ALT)
    hold_speed(CRUISE_SPEED)
    if int(craft.time() / dt) % 5 == 0:
        mark_scan()
    else:
        # Planning runs on the other ticks so marking and searching never share a tick's budget.
        if plan["done"] and craft.time() - plan["t_last"] >= REPLAN:
            start_plan()
            plan["t_last"] = craft.time()
        if not plan["done"]:
            step_plan()
    follow_path()
    craft.plot("path_cells", len(plan["path"]))
"""#
    static let l10Starter = #"""
import craft
import math

CRUISE_ALT = 80.0
CRUISE_SPEED = 30.0
ALPHA_MAX = 0.17         # rad, 10 deg below the 15 deg stall
MAX_TURN = 0.33          # rad/s heading rate, 45 deg bank at 30 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

trim = {"i": 0.05}

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    err = target - craft.altitude()
    # Integral trim removes the steady height error (the wing needs a few degrees of nose-up).
    trim["i"] = math.clamp(trim["i"] + 0.0004 * err, -0.05, 0.2)
    want = math.clamp(trim["i"] + 0.03 * err - 0.1 * vz, -0.2, 0.3)
    # Keep the wing below stall: nose at most ALPHA_MAX above the flight path.
    v = craft.velocity()
    gamma = math.atan2(v[2], math.hypot(v[0], v[1]))
    want = min(want, gamma + ALPHA_MAX)
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
"""#
    static let l10Reference = #"""
import craft
import math

CRUISE_ALT = 80.0
CRUISE_SPEED = 30.0
ALPHA_MAX = 0.17         # rad, 10 deg below the 15 deg stall
MAX_TURN = 0.33          # rad/s heading rate, 45 deg bank at 30 m/s

def wrap(a):
    while a > math.pi:
        a = a - 2.0 * math.pi
    while a < -math.pi:
        a = a + 2.0 * math.pi
    return a

trim = {"i": 0.05}

def hold_altitude(target):
    pitch, yaw, roll = craft.attitude()
    vz = craft.velocity()[2]
    err = target - craft.altitude()
    # Integral trim removes the steady height error (the wing needs a few degrees of nose-up).
    trim["i"] = math.clamp(trim["i"] + 0.0004 * err, -0.05, 0.2)
    want = math.clamp(trim["i"] + 0.03 * err - 0.1 * vz, -0.2, 0.3)
    # Keep the wing below stall: nose at most ALPHA_MAX above the flight path.
    v = craft.velocity()
    gamma = math.atan2(v[2], math.hypot(v[0], v[1]))
    want = min(want, gamma + ALPHA_MAX)
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

# Lesson 10 reference: the lesson 6 vector field histogram, holding the finish gate's height.
# Pseudocode from stage 2:
#   build a 36-sector polar histogram of obstacle density from the lidar scan
#   smooth it, mark sectors below THRESHOLD as free
#   pick the free sector closest to the goal direction, with free neighbours
#   steer toward that sector

THRESHOLD = 0.8
VALLEY = 1            # free neighbours needed each side
W_GOAL = 1.0
WIDE = 3              # sectors kept between the path and a valley edge
W_HEADING = 0.5
W_PREV = 1.0

vfh = {"prev": -999.0, "prev_abs": -999.0}
TURN_GAIN = 1.5
MAX_RANGE = 120.0
R_SAFE = 10.0         # m, craft half span plus margin

def histogram():
    h = []
    for k in range(36):
        h.append(0.0)
    for hit in craft.lidar_scan():
        a, d = hit
        if d > 0.0 and d < MAX_RANGE:
            w = 1.0 - d / MAX_RANGE
            # Enlarge each hit by the safety radius seen from the craft (VFH+).
            spread = math.degrees(math.asin(min(1.0, R_SAFE / d)))
            k0 = int(math.floor((a - spread + 180.0) / 10.0))
            k1 = int(math.floor((a + spread + 180.0) / 10.0))
            for k in range(k0, k1 + 1):
                h[(k + 36) % 36] = h[(k + 36) % 36] + w * w
    return h

def smooth(h):
    s = []
    for k in range(36):
        s.append((h[(k + 35) % 36] + 2.0 * h[k] + h[(k + 1) % 36]) / 4.0)
    return s

def pick_sector(s, goal_deg):
    # Valleys: runs of free sectors within 90 deg of the nose. In a wide valley aim WIDE sectors
    # in from the edge nearest the goal (or at the goal if it lies inside); in a narrow one, its middle.
    best = None
    best_cost = 1.0e9
    k = 9
    while k <= 26:
        if s[k] >= THRESHOLD:
            k = k + 1
            continue
        start = k
        while k <= 26 and s[k] < THRESHOLD:
            k = k + 1
        stop = k - 1
        lo = start * 10.0 - 180.0 + 5.0
        hi = stop * 10.0 - 180.0 + 5.0
        if stop - start + 1 < 2 * VALLEY + 1:
            continue
        if stop - start + 1 >= 2 * WIDE:
            a_lo = lo + (WIDE - 1) * 10.0
            a_hi = hi - (WIDE - 1) * 10.0
            target = min(max(goal_deg, a_lo), a_hi)
        else:
            target = (lo + hi) / 2.0
        cost = W_GOAL * abs(target - goal_deg) + W_HEADING * abs(target)
        if vfh["prev"] > -900.0:
            # Hysteresis: stay with the valley picked last tick instead of flipping sides.
            cost = cost + W_PREV * abs(math.degrees(wrap(math.radians(target - vfh["prev"]))))
        if cost < best_cost:
            best_cost = cost
            best = target
    return best

def least_dense(s):
    # Fallback when nothing is free: the emptiest sector ahead.
    best = 0.0
    low = 1.0e9
    for k in range(36):
        centre = k * 10.0 - 180.0 + 5.0
        if abs(centre) <= 90.0 and s[k] < low:
            low = s[k]
            best = centre
    return best

cfg = {"alt": CRUISE_ALT}

def setup():
    cfg["alt"] = craft.goal_position()[2]

def update(dt):
    hold_altitude(cfg["alt"])
    hold_speed(CRUISE_SPEED)
    gb, ge, gd = craft.goal()
    s = smooth(histogram())
    pitch, yaw, roll = craft.attitude()
    if vfh["prev_abs"] > -900.0:
        vfh["prev"] = math.degrees(wrap(math.radians(vfh["prev_abs"]) - yaw))
    angle = pick_sector(s, math.degrees(gb))
    if angle is not None:
        vfh["prev_abs"] = math.degrees(yaw) + angle
    if angle is None:
        angle = least_dense(s)
        turn(TURN_GAIN * math.radians(angle))
    else:
        turn(TURN_GAIN * math.radians(angle))
    craft.plot("heading_deg", angle)
"""#
}
