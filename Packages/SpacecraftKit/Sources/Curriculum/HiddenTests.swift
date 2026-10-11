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
        4: [
            ("test_offset_sign", { h in
                h.values["position"] = .vec(0, 0, 120); h.values["goal_position"] = .vec(0, 1600, 120)
                h.call("setup")
                h.values["position"] = .vec(10, 100, 120)
                return (h.call("mline_offset")?.number ?? 0) > 0
            }),
            ("test_hit_stores_goal_distance", { h in
                h.values["goal_position"] = .vec(0, 1600, 120); h.call("setup")
                h.lidarAt = { _ in 50 }; h.values["goal"] = .vec(0, 0, 800)
                h.call("update", [.float(0.02)])
                return h.entry("bug", "mode")?.text == "follow" && near(h.entry("bug", "hit_d")?.number, 800, 1)
            }),
            ("test_follow_turns_left_on_front", { h in
                h.values["goal_position"] = .vec(0, 1600, 120); h.call("setup")
                h.setEntry("bug", "mode", .str("follow")); h.lidarAt = { _ in 50 }; h.values["goal"] = .vec(0, 0, 800)
                h.call("update", [.float(0.02)])
                return (h.last("set_yaw") ?? 0) < 0
            }),
            ("test_leave_requires_progress", { h in
                h.values["goal_position"] = .vec(0, 1600, 120); h.call("setup")
                h.setEntry("bug", "mode", .str("follow")); h.setEntry("bug", "away", .bool(true))
                h.setEntry("bug", "hit_d", .float(800)); h.lidarAt = { _ in -1 }
                h.values["position"] = .vec(0, 800, 120); h.values["goal"] = .vec(0, 0, 798)
                h.call("update", [.float(0.02)])
                return h.entry("bug", "mode")?.text == "follow"
            }),
            ("test_leave_requires_mline", { h in
                h.values["goal_position"] = .vec(0, 1600, 120); h.call("setup")
                h.setEntry("bug", "mode", .str("follow")); h.setEntry("bug", "away", .bool(true))
                h.setEntry("bug", "hit_d", .float(800)); h.lidarAt = { _ in -1 }
                h.values["position"] = .vec(40, 900, 120); h.values["goal"] = .vec(0, 0, 700)
                h.call("update", [.float(0.02)])
                let stayed = h.entry("bug", "mode")?.text == "follow"
                h.values["position"] = .vec(0, 900, 120)
                h.call("update", [.float(0.02)])
                return stayed && h.entry("bug", "mode")?.text == "go"
            }),
        ],
        5: [
            ("test_attraction_only_points_at_goal", { h in
                h.lidarAt = { _ in -1 }; h.values["goal"] = .vec(0.5, 0, 1000)
                let f = h.call("force")?.items.compactMap(\.number) ?? []
                return f.count == 2 && near(atan2(f[0], f[1]), 0.5, 1e-6)
            }),
            ("test_repulsion_zero_beyond_r0", { h in
                h.lidarAt = { _ in 500 }; h.values["goal"] = .vec(0.3, 0, 1000)
                let f = h.call("force")?.items.compactMap(\.number) ?? []
                return f.count == 2 && near(atan2(f[0], f[1]), 0.3, 1e-6)
            }),
            ("test_repulsion_grows_closer", { h in
                h.values["goal"] = .vec(0, 0, 1000)
                h.lidarAt = { a in a == 0 ? 90 : -1 }
                let far = h.call("force")?.items.compactMap(\.number).last ?? 0
                h.lidarAt = { a in a == 0 ? 40 : -1 }
                let close = h.call("force")?.items.compactMap(\.number).last ?? 0
                return close < far
            }),
            ("test_symmetric_hits_cancel_sideways", { h in
                h.values["goal"] = .vec(0, 0, 1000)
                h.lidarAt = { a in abs(a) == 30 ? 60 : -1 }
                let f = h.call("force")?.items.compactMap(\.number) ?? [1, 0]
                return abs(f[0]) < 1e-6
            }),
            ("test_escape_after_stall", { h in
                h.lidarAt = { _ in -1 }; h.values["goal"] = .vec(0, 0, 995)
                h.setEntry("pf", "t_check", .float(0)); h.setEntry("pf", "d_check", .float(1000))
                h.values["time"] = .float(20)
                h.call("force")
                return (h.entry("pf", "escape_until")?.number ?? -1) > 20
            }),
        ],
    ]
}
