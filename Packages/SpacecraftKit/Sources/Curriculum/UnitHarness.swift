import Foundation
import FlightCode

/// Runs player code against scripted sensor values for the hidden unit tests of specs/15
/// ("hidden tests call update with recorded sensor frames and check commands").
public final class UnitHarness: VMHost {
    public let vm: VM
    /// Scripted craft API answers by call name; `lidar` answers by angle through `lidarAt`.
    public var values: [String: Value] = [:]
    public var lidarAt: (Double) -> Double = { _ in -1 }
    public private(set) var commands: [(name: String, value: Double)] = []
    public private(set) var logs: [String] = []

    public init(source: String) throws {
        let p = try Compiler.compile(source)
        vm = VM(program: p, host: nil)
        vm.host = self
        try vm.load()
    }

    public func reset() { commands.removeAll(); logs.removeAll() }

    public func last(_ name: String) -> Double? { commands.last { $0.name == name }?.value }

    public func craftCall(_ name: String, _ args: [Value]) throws -> Value {
        switch name {
        case "set_throttle", "set_pitch", "set_yaw", "set_roll":
            commands.append((name, args.first?.asDouble ?? 0)); return .none
        case "stage": commands.append((name, 0)); return .none
        case "log": logs.append(args.map(\.repr).joined(separator: " ")); return .none
        case "plot": return .none
        case "lidar": return .float(lidarAt(args.first?.asDouble ?? 0))
        case "lidar_scan":
            if let v = values[name] { return v }
            return .list(ListRef(stride(from: -180, to: 180, by: 10).map { .tuple([.float(Double($0)), .float(lidarAt(Double($0)))]) }))
        default:
            if let v = values[name] { return v }
            switch name {
            case "position", "velocity", "goal_position": return .vec(0, 0, 0)
            case "attitude": return .vec(.pi / 2, 0, 0)
            case "next_gate", "goal": return .vec(0, 0, 100)
            case "radar", "radar_tracks", "camera_objects": return .list(ListRef([]))
            case "mass": return .float(1000)
            case "thrust_max": return .float(24_000)
            default: return .float(0)
            }
        }
    }

    /// Call a function; nil when it faults.
    @discardableResult
    public func call(_ name: String, _ args: [Value] = []) -> Value? {
        try? vm.call(name, args)
    }

    public func set(_ name: String, _ v: Double) { vm.setGlobal(name, .float(v)) }

    /// A dict global's entry, e.g. bug["mode"].
    public func entry(_ dict: String, _ key: String) -> Value? {
        guard case let .dict(d)? = vm.global(dict) else { return nil }
        return d.map[.str(key)]?.value
    }

    public func setEntry(_ dict: String, _ key: String, _ v: Value) {
        guard case let .dict(d)? = vm.global(dict) else { return }
        d.set(.str(key), key: .str(key), v)
    }
}

public extension Value {
    var number: Double? { asDouble }
    var text: String? { if case let .str(s) = self { return s }; return nil }
    var items: [Value] {
        switch self { case let .tuple(t): t; case let .list(l): l.items; default: [] }
    }
}
