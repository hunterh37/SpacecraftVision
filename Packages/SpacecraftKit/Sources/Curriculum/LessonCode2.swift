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
}
