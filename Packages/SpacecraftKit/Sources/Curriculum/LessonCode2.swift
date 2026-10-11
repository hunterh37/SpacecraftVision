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
}
