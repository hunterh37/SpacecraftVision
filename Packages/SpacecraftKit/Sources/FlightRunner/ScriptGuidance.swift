import Foundation
import SpacecraftCore
import FlightSim
import FlightCode

/// One recorded guidance command, for hidden tests and analysis.
public struct CommandEvent: Sendable, Hashable {
    public var t: Double
    public var name: String
    public var value: Double
    public var altitude: Double
    public var vz: Double
}

/// Runs a compiled Python-subset program as the craft's guidance, exposing the craft API of specs/05.
public final class ScriptGuidance: FlightGuidance, VMHost {
    public let program: Program
    public let vm: VM
    weak var sim: FlightSimulation?
    public private(set) var activeLine: Int?
    public private(set) var commands: [CommandEvent] = []
    private var sensorFaults: Set<String> = []
    private var started = false
    private var startTime = 0.0

    public init(source: String) throws {
        program = try Compiler.compile(source)
        vm = VM(program: program, host: nil)
        vm.host = self
    }

    public func attach(to sim: FlightSimulation) {
        self.sim = sim
        sim.guidance = self
    }

    public func setup(_ sim: FlightSimulation) -> GuidanceTickResult {
        self.sim = sim
        do {
            try vm.load()
            try vm.call("setup", [], budget: VM.setupBudget)
            activeLine = vm.currentLine
            return .ok
        } catch {
            activeLine = error.line
            return .fault(message: error.message, line: error.line)
        }
    }

    public func update(_ sim: FlightSimulation, dt: Double) -> GuidanceTickResult {
        if !started { started = true; startTime = sim.time }
        do {
            try vm.call("update", [.float(dt)])
            activeLine = vm.currentLine
            return .ok
        } catch {
            activeLine = error.line
            return .fault(message: error.message, line: error.line)
        }
    }

    // MARK: Craft API

    func num(_ args: [Value], _ i: Int, _ call: String) throws -> Double {
        guard i < args.count, let d = args[i].asDouble else {
            throw VMFault(.type, "craft.\(call)() expects a number")
        }
        return d
    }

    func record(_ name: String, _ v: Double) {
        guard let sim else { return }
        commands.append(CommandEvent(t: sim.time - startTime, name: name, value: v, altitude: sim.altitude, vz: sim.velocity.z))
    }

    func sensor(_ call: String, part: String, empty: Value, emptyText: String) -> Value {
        if !sensorFaults.contains(call) {
            sensorFaults.insert(call)
            sim?.recordFault(line: vm.currentLine, message: "\(call) needs a \(part); it returns \(emptyText) without one")
        }
        return empty
    }

    public func craftCall(_ name: String, _ args: [Value]) throws -> Value {
        guard let sim else { throw VMFault(.name, "craft is not connected") }
        switch name {
        case "position": return .vec(sim.position.x, sim.position.y, sim.position.z)
        case "velocity": return .vec(sim.velocity.x, sim.velocity.y, sim.velocity.z)
        case "attitude": return .vec(sim.pitch, sim.yaw, sim.roll)
        case "altitude": return .float(sim.altitude)
        case "fuel": return .float(sim.fuelFraction)
        case "energy": return .float(sim.energyFraction)
        case "temperature": return .float(sim.course.timeOfDay.ambientK)
        case "time": return .float(sim.time - startTime)
        case "mass": return .float(sim.mass)
        case "thrust_max": return .float(sim.thrustMax)
        case "random": return .float(sim.random.unit())
        case "next_gate":
            guard sim.mission.lesson.map({ $0 <= 7 }) ?? true, let g = sim.nextGate else { return .vec(0, 0, -1) }
            let (b, e, d) = sim.relative(to: g.centre)
            return .vec(b, e, d)
        case "goal":
            let (b, e, d) = sim.relative(to: sim.course.goal)
            return .vec(b, e, d)
        case "goal_position": return .vec(sim.course.goal.x, sim.course.goal.y, sim.course.goal.z)
        case "set_throttle": let v = try num(args, 0, name); sim.setThrottle(v); record(name, v); return .none
        case "set_pitch": let v = try num(args, 0, name); sim.setPitchRate(v); record(name, v); return .none
        case "set_yaw": let v = try num(args, 0, name); sim.setYawRate(v); record(name, v); return .none
        case "set_roll": let v = try num(args, 0, name); sim.setRollRate(v); record(name, v); return .none
        case "stage": sim.stage(); record(name, 0); return .none
        case "log": sim.log(args.map(\.repr).joined(separator: " ")); return .none
        case "plot":
            guard args.count == 2, case let .str(n) = args[0] else { throw VMFault(.type, "craft.plot(name, value) expects a string and a number") }
            sim.plot(n, try num(args, 1, name)); return .none
        case "lidar":
            if sim.partIds.contains("lidar-sensor") { return .float(-1) }
            return sensor("craft.lidar", part: "lidar-sensor", empty: .float(-1), emptyText: "-1")
        case "lidar_scan":
            if sim.partIds.contains("lidar-sensor") {
                return .list(ListRef(stride(from: -180, to: 180, by: 10).map { .tuple([.float(Double($0)), .float(-1)]) }))
            }
            return sensor("craft.lidar_scan", part: "lidar-sensor", empty: .list(ListRef([])), emptyText: "an empty list")
        case "radar", "radar_tracks":
            if sim.partIds.contains("radar-sensor") { return .list(ListRef([])) }
            return sensor("craft.\(name)", part: "radar-sensor", empty: .list(ListRef([])), emptyText: "an empty list")
        case "camera_objects":
            if sim.partIds.contains("camera-sensor") { return .list(ListRef([])) }
            return sensor("craft.camera_objects", part: "camera-sensor", empty: .list(ListRef([])), emptyText: "an empty list")
        default:
            throw VMFault(.name, "craft has no function '\(name)'")
        }
    }
}

/// Craft API reference shown in the editor (specs/05).
public enum CraftAPIReference {
    public static let entries: [(call: String, doc: String)] = [
        ("craft.altitude()", "Altitude above the pad, m"),
        ("craft.position()", "(x, y, z) m, x east, y north, z up"),
        ("craft.velocity()", "(vx, vy, vz) m/s"),
        ("craft.attitude()", "(pitch, yaw, roll) rad; pitch 90 deg is straight up"),
        ("craft.fuel()", "Propellant left, 0..1"),
        ("craft.energy()", "Battery left, 0..1"),
        ("craft.time()", "Seconds since the first update"),
        ("craft.mass()", "Current mass, kg"),
        ("craft.thrust_max()", "Thrust at full throttle now, N"),
        ("craft.next_gate()", "(bearing, elevation, distance) to the next gate"),
        ("craft.goal()", "(bearing, elevation, distance) to the finish"),
        ("craft.set_throttle(x)", "0..1; below 0.4 clamps to 0.4, 0 shuts down"),
        ("craft.set_pitch(r)", "Pitch rate, rad/s, limit 0.5"),
        ("craft.set_yaw(r)", "Yaw rate, rad/s, limit 0.5"),
        ("craft.stage()", "Fire the next stage: drogue, then main"),
        ("craft.log(v)", "Show v in telemetry"),
        ("craft.plot(name, v)", "Add a point to a named plot"),
    ]
}
