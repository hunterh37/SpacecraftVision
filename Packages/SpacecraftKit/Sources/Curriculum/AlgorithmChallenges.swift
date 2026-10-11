import Foundation

/// Optional missions that let players compare guidance strategies on the same hop course.
public struct AlgorithmChallenge: Sendable, Identifiable {
    public let id: String
    public let strategy: String
    public let buildReason: String
    public let tuningHint: String
    public let starterCode: String
    public let referenceCode: String

    public static let clockwork = AlgorithmChallenge(
        id: "M1T", strategy: "Open-loop timer",
        buildReason: "The burn time depends on the craft's mass and thrust. Change the build and retune the clock.",
        tuningHint: "Tune BURN_TIME until apogee falls between 1,050 and 1,150 m.",
        starterCode: timedSource.replacingOccurrences(of: "BURN_TIME = 4.0", with: "BURN_TIME = 3.0"),
        referenceCode: timedSource)

    public static let predictive = AlgorithmChallenge(
        id: "M1P", strategy: "Drag-aware apogee prediction",
        buildReason: "Carry a 35 kg payload under a tighter budget. The heavier build changes when the engine should stop.",
        tuningHint: "Tune DRAG_FACTOR so the predicted apogee triggers cutoff for a 1,080–1,120 m flight.",
        starterCode: predictiveSource.replacingOccurrences(of: "DRAG_FACTOR = 0.48", with: "DRAG_FACTOR = 0.30"),
        referenceCode: predictiveSource)

    public static let all = [clockwork, predictive]
    public static func named(_ missionID: String) -> AlgorithmChallenge? { all.first { $0.id == missionID } }

    private static let timedSource = #"""
import craft

# Open-loop guidance: stop the engine after a fixed time.
# A different build changes the acceleration, so the same time may miss.
BURN_TIME = 4.0
MAIN_ALT = 250.0
state = {"phase": "boost"}

def setup():
    craft.set_throttle(1.0)

def update(dt):
    alt = craft.altitude()
    vz = craft.velocity()[2]
    if state["phase"] == "boost" and craft.time() >= BURN_TIME:
        craft.set_throttle(0.0)
        state["phase"] = "coast"
    if state["phase"] == "coast" and vz < 0.0:
        craft.stage()
        state["phase"] = "drogue"
    if state["phase"] == "drogue" and alt < MAIN_ALT:
        craft.stage()
        state["phase"] = "main"
    craft.log(state["phase"])
    craft.plot("altitude", alt)
"""#

    private static let predictiveSource = #"""
import craft

# Feedback guidance: predict the coast from current height and speed.
# DRAG_FACTOR estimates how much the atmosphere shortens a ballistic coast.
TARGET_APOGEE = 1100.0
DRAG_FACTOR = 0.48
MAIN_ALT = 250.0
G = 9.80665
state = {"phase": "boost"}

def setup():
    craft.set_throttle(1.0)

def update(dt):
    alt = craft.altitude()
    vz = craft.velocity()[2]
    climb = max(0.0, vz)
    predicted = alt + DRAG_FACTOR * climb * climb / (2.0 * G)
    if state["phase"] == "boost" and predicted >= TARGET_APOGEE:
        craft.set_throttle(0.0)
        state["phase"] = "coast"
    if state["phase"] == "coast" and vz < 0.0:
        craft.stage()
        state["phase"] = "drogue"
    if state["phase"] == "drogue" and alt < MAIN_ALT:
        craft.stage()
        state["phase"] = "main"
    craft.log(state["phase"])
    craft.plot("predicted_apogee", predicted)
"""#
}
