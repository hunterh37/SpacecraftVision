// Generated from specs/15-missions-courses.md starter and reference code.
enum LessonCode {
    static let l0Starter = #"""
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
"""#
    static let l0Reference = #"""
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
"""#
    static let l1Starter = #"""
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
"""#
    static let l1Reference = #"""
import craft
import math

# Lesson 1: feedback. A P controller holds the pitch program.
# Pseudocode from stage 2:
#   error = target pitch - measured pitch
#   pitch rate command = KP * error
#   same for yaw with target 0

CUTOFF_ALT = 360.0
MAIN_ALT = 250.0
KP = 2.0

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
    craft.set_pitch(KP * err)
    craft.set_yaw(KP * wrap(0.0 - yaw))
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
"""#
    static let l2Starter = #"""
import craft
import math

# Lesson 2: PID on heading to the next gate.
# Pseudocode from stage 2:
#   error = bearing to next gate
#   integral += error * dt
#   derivative = (error - previous error) / dt
#   yaw rate = KP * error + KI * integral + KD * derivative

G = 9.80665
CRUISE_SPEED = 25.0      # m/s horizontal
KP = 0.0
KI = 0.0
KD = 0.0
I_LIMIT = 1.0            # rad s, integral clamp

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
    accel = math.clamp(0.8 * (target_alt - craft.altitude()) - 1.2 * vz, -4.0, 4.0)
    s = max(math.sin(pitch), 0.3)
    return math.clamp(craft.mass() * (G + accel) / (craft.thrust_max() * s), 0.4, 1.0)

def hold_speed_pitch(target_speed):
    v = craft.velocity()
    vh = math.hypot(v[0], v[1])
    tilt = math.clamp(math.radians(1.5) * (target_speed - vh), 0.0, math.radians(25.0))
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
    hold_speed_pitch(CRUISE_SPEED)
    craft.set_yaw(heading_pid(bearing, dt))
    craft.plot("bearing_deg", math.degrees(bearing))
"""#
    static let l2Reference = #"""
import craft
import math

# Lesson 2: PID on heading to the next gate.
# Pseudocode from stage 2:
#   error = bearing to next gate
#   integral += error * dt
#   derivative = (error - previous error) / dt
#   yaw rate = KP * error + KI * integral + KD * derivative

G = 9.80665
CRUISE_SPEED = 25.0      # m/s horizontal
KP = 1.2
KI = 0.05
KD = 0.4
I_LIMIT = 1.0            # rad s, integral clamp

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
    accel = math.clamp(0.8 * (target_alt - craft.altitude()) - 1.2 * vz, -4.0, 4.0)
    s = max(math.sin(pitch), 0.3)
    return math.clamp(craft.mass() * (G + accel) / (craft.thrust_max() * s), 0.4, 1.0)

def hold_speed_pitch(target_speed):
    v = craft.velocity()
    vh = math.hypot(v[0], v[1])
    tilt = math.clamp(math.radians(1.5) * (target_speed - vh), 0.0, math.radians(25.0))
    pitch, yaw, roll = craft.attitude()
    craft.set_pitch(2.0 * ((math.pi / 2.0 - tilt) - pitch))

def heading_pid(err, dt):
    pid["integral"] = math.clamp(pid["integral"] + err * dt, -I_LIMIT, I_LIMIT)
    if pid["first"]:
        deriv = 0.0
        pid["first"] = False
    else:
        deriv = wrap(err - pid["prev"]) / dt
    pid["prev"] = err
    return KP * err + KI * pid["integral"] + KD * deriv

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
    hold_speed_pitch(CRUISE_SPEED)
    craft.set_yaw(heading_pid(bearing, dt))
    craft.plot("bearing_deg", math.degrees(bearing))
"""#
}
