import Foundation
import FlightCode

/// Hidden unit tests of specs/15: each builds a fresh harness from the player's code, sets scripted
/// sensor values and checks function results or commands. A test that faults counts as failed.
public enum HiddenTests {
    public static func run(lesson: Int, source: String) -> [HiddenTestResult] {
        guard let cases = suites[lesson] else { return [] }
        return cases.map { name, check in
            let ok: Bool
            if let h = try? UnitHarness(source: source) { ok = check(h) } else { ok = false }
            return HiddenTestResult(name: name, passed: ok)
        }
    }

    public static func names(lesson: Int) -> [String] { suites[lesson]?.map(\.0) ?? [] }

    typealias Case = (String, (UnitHarness) -> Bool)

    static func near(_ a: Double?, _ b: Double, _ tol: Double = 1e-6) -> Bool { a.map { abs($0 - b) <= tol } ?? false }

    nonisolated(unsafe) static let suites: [Int: [Case]] = [
        2: [
            ("test_p_term_only", { h in
                h.set("KP", 1.2); h.set("KI", 0); h.set("KD", 0)
                return near(h.call("heading_pid", [.float(0.3), .float(0.02)])?.number, 0.36)
            }),
            ("test_integral_accumulates", { h in
                h.set("KP", 0); h.set("KI", 1); h.set("KD", 0)
                h.call("heading_pid", [.float(0.2), .float(0.02)])
                return near(h.call("heading_pid", [.float(0.2), .float(0.02)])?.number, 0.008, 1e-6)
            }),
            ("test_integral_clamped", { h in
                h.set("KP", 0); h.set("KI", 1); h.set("KD", 0); h.set("I_LIMIT", 1)
                let out = h.call("heading_pid", [.float(100), .float(1)])?.number ?? 99
                return abs(out) <= 1 + 1e-9
            }),
            ("test_derivative_no_kick_first_tick", { h in
                h.set("KP", 0); h.set("KI", 0); h.set("KD", 1)
                return near(h.call("heading_pid", [.float(0.5), .float(0.02)])?.number, 0)
            }),
            ("test_derivative_wraps", { h in
                h.set("KP", 0); h.set("KI", 0); h.set("KD", 1)
                h.call("heading_pid", [.float(3.1), .float(0.02)])
                let d = h.call("heading_pid", [.float(-3.1), .float(0.02)])?.number ?? 1e9
                return abs(d) < 10
            }),
        ],
        3: [
            ("test_go_when_clear", { h in
                h.lidarAt = { _ in -1 }
                h.values["next_gate"] = .vec(0.2, 0, 300); h.values["velocity"] = .vec(0, 8, 0)
                h.call("update", [.float(0.02)])
                return h.entry("bug", "mode")?.text == "go" && h.last("set_yaw") != nil
            }),
            ("test_turn_on_close_front", { h in
                h.lidarAt = { _ in 20 }
                h.values["next_gate"] = .vec(0, 0, 300); h.values["velocity"] = .vec(0, 8, 0)
                h.call("update", [.float(0.02)])
                return h.entry("bug", "mode")?.text == "turn"
            }),
            ("test_turn_toward_open_side", { h in
                h.lidarAt = { a in a < 0 ? 20 : (a > 25 ? -1 : 20) }
                h.values["next_gate"] = .vec(0, 0, 300); h.values["velocity"] = .vec(0, 8, 0)
                h.call("update", [.float(0.02)])
                return h.entry("bug", "side")?.number.map { $0 > 0 } ?? false
            }),
            ("test_resume_when_goal_clear", { h in
                h.setEntry("bug", "mode", .str("turn"))
                h.lidarAt = { _ in -1 }
                h.values["next_gate"] = .vec(0, 0, 300); h.values["velocity"] = .vec(0, 8, 0)
                h.call("update", [.float(0.02)])
                return h.entry("bug", "mode")?.text == "go"
            }),
            ("test_no_return_minus_one_as_close", { h in
                h.lidarAt = { _ in -1 }
                h.values["next_gate"] = .vec(0, 0, 300); h.values["velocity"] = .vec(0, 8, 0)
                for _ in 0..<5 { h.call("update", [.float(0.02)]) }
                return h.entry("bug", "mode")?.text == "go"
            }),
        ],
    ]
}
