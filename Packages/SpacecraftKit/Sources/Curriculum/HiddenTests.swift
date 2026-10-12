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


    static func scan(_ hits: [(Double, Double)]) -> Value {
        .list(ListRef(stride(from: -180, to: 180, by: 10).map { a in
            let d = hits.first { $0.0 == Double(a) }?.1 ?? -1
            return .tuple([.float(Double(a)), .float(d)])
        }))
    }

    /// 36 smoothed sector values from a rule on the sector index.
    static func sectors(_ f: (Int) -> Double) -> Value { .list(ListRef((0..<36).map { .float(f($0)) })) }

    static func gridKey(_ i: Int, _ j: Int) -> Int { (i + 5000) * 100000 + (j + 5000) }

    /// Plans from (0, 0) to (5, 95) with the given grid keys blocked; nil if planning faults or never finishes.
    static func plan(_ h: UnitHarness, blocked: [Int]) -> [Int]? {
        h.values["goal_position"] = .vec(5, 95, 80)
        guard h.call("setup") != nil, case let .dict(g)? = h.vm.global("grid") else { return nil }
        for k in blocked { g.set(.int(k), key: .int(k), .float(0)) }
        guard h.call("start_plan") != nil else { return nil }
        for _ in 0..<50 {
            guard h.call("step_plan") != nil else { return nil }
            if case .bool(true)? = h.entry("plan", "done") { break }
        }
        guard case .bool(true)? = h.entry("plan", "done") else { return nil }
        let p = h.entry("plan", "path")?.items.compactMap { v -> Int? in if case let .int(i) = v { i } else { nil } } ?? []
        return p.isEmpty ? nil : p
    }

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
        6: [
            ("test_histogram_bins", { h in
                h.values["lidar_scan"] = scan([(0, 60)])
                let bins = h.call("histogram")?.items.compactMap(\.number) ?? []
                return bins.count == 36 && near(bins[18], 0.25, 1e-6) && bins[0] == 0 && bins[9] == 0
            }),
            ("test_smooth_wraps", { h in
                var bins = [Value](repeating: .float(0), count: 36); bins[0] = .float(4)
                let s = h.call("smooth", [.list(ListRef(bins))])?.items.compactMap(\.number) ?? []
                return s.count == 36 && near(s[0], 2) && near(s[35], 1) && near(s[1], 1)
            }),
            ("test_pick_closest_to_goal", { h in
                let a = h.call("pick_sector", [sectors { _ in 0 }, .float(30)])?.number
                return near(a, 30, 0.5)
            }),
            ("test_pick_requires_wide_valley", { h in
                let narrow = h.call("pick_sector", [sectors { $0 == 18 || $0 == 19 ? 0 : 5 }, .float(0)])
                let wide = h.call("pick_sector", [sectors { (17...19).contains($0) ? 0 : 5 }, .float(0)])?.number
                if case .none? = narrow { return near(wide, 5, 0.5) }
                return false
            }),
            ("test_none_when_blocked", { h in
                if case .none? = h.call("pick_sector", [sectors { _ in 5 }, .float(0)]) { return true }
                return false
            }),
        ],
        8: [
            ("test_heap_order", { h in
                let heap = Value.list(ListRef([]))
                for (f, k) in [(5.0, 1), (1.0, 2), (3.0, 3), (4.0, 4)] {
                    h.call("heap_push", [heap, .tuple([.float(f), .int(k)])])
                }
                let out = (0..<4).compactMap { _ in h.call("heap_pop", [heap])?.items.first?.number }
                return out == [1, 3, 4, 5]
            }),
            ("test_astar_straight_line", { h in
                guard let path = plan(h, blocked: []) else { return false }
                return path.count == 10 && path.allSatisfy { h.call("cell_i", [.int($0)])?.number == 0 }
            }),
            ("test_astar_around_block", { h in
                let wall = (-1...1).map { gridKey($0, 4) }
                guard let path = plan(h, blocked: wall), let last = path.last else { return false }
                let hd = h.call("heuristic", [.int(last)])?.number ?? 99
                return path.allSatisfy { !wall.contains($0) } && hd < 10
            }),
            ("test_inflate_marks_square", { h in
                h.vm.setGlobal("INFLATE", .int(1))
                h.values["lidar_scan"] = scan([(0, 55)])
                h.values["attitude"] = .vec(0, 0, 0)
                h.call("mark_scan")
                guard case let .dict(g)? = h.vm.global("grid") else { return false }
                let want = Set((-1...1).flatMap { i in (4...6).map { gridKey(i, $0) } })
                let got = Set(g.order.compactMap { k -> Int? in if case let .int(v) = k { v } else { nil } })
                return got == want
            }),
            ("test_budget_per_tick", { h in
                h.values["goal_position"] = .vec(0, 2400, 80)
                h.values["goal"] = .vec(0, 0, 2400)
                h.values["attitude"] = .vec(0, 0, 0)
                h.values["lidar_scan"] = scan([(-30, 40), (-20, 45), (0, 70), (20, 50), (40, 35), (90, 30), (-90, 30)])
                h.call("setup")
                for t in 0..<100 {
                    h.values["time"] = .float(Double(t) * 0.02)
                    if h.call("update", [.float(0.02)]) == nil { return false }
                }
                return true
            }),
        ],
        7: [
            ("test_cpa_head_on", { h in
                h.set("HORIZON", 20)
                return near(h.call("closest_approach", [.vec(100, 0, 0), .vec(-10, 0, 0)])?.number, 0, 1e-6)
            }),
            ("test_cpa_receding_is_now", { h in
                h.set("HORIZON", 20)
                return near(h.call("closest_approach", [.vec(50, 0, 0), .vec(10, 0, 0)])?.number, 50, 1e-6)
            }),
            ("test_cpa_clamped_to_horizon", { h in
                h.set("HORIZON", 5)
                return near(h.call("closest_approach", [.vec(100, 0, 0), .vec(-10, 0, 0)])?.number, 50, 1e-6)
            }),
            ("test_candidate_rejected_in_cone", { h in
                h.set("HORIZON", 8); h.set("MARGIN", 20)
                // Candidate closing at 12 m/s on a 5 m rock 60 m away: closest approach 0, inside the cone.
                return (h.call("closest_approach", [.vec(60, 0, 0), .vec(-12, 0, 0)])?.number ?? 99) < 25
            }),
            ("test_pick_nearest_preferred", { h in
                h.values["position"] = .vec(0, 0, 3000); h.values["velocity"] = .vec(0, 0, 100)
                h.call("update", [.float(0.02)])
                return near(h.last("set_yaw"), 0, 1e-9) && !h.logs.contains("no safe velocity")
            }),
        ],
        9: [
            ("test_tree_grows_from_start", { h in
                let path = h.call("build", [.vec(10, 20, 3000), .vec(0, 0, 100), .list(ListRef([]))])?.items ?? []
                let first = path.first?.items.compactMap(\.number) ?? []
                return first.count == 3 && near(first[0], 10) && near(first[1], 20) && near(first[2], 3000)
            }),
            ("test_edge_rejects_predicted_hit", { h in
                let rock: Value = .tuple([.vec(0, 0, 100), .vec(0, 0, -100), .float(5)])
                let ok = h.call("edge_clear", [.vec(0, 0, 0), .vec(0, 0, 200), .list(ListRef([rock])), .vec(0, 0, 0), .vec(0, 0, 100)])
                return ok?.truthy == false
            }),
            ("test_goal_bias_rate", { h in
                let path = h.call("build", [.vec(0, 0, 3000), .vec(0, 0, 100), .list(ListRef([]))])?.items ?? []
                let top = path.last?.items.compactMap(\.number).last ?? 0
                return top > 3000 + 200
            }),
            ("test_smoothing_keeps_clear_path", { h in
                let rock: Value = .tuple([.vec(0, 0, 300), .vec(0, 0, -100), .float(6)])
                let tracks: Value = .list(ListRef([rock]))
                let path = h.call("build", [.vec(0, 0, 3000), .vec(0, 0, 100), tracks])?.items ?? []
                guard path.count >= 2 else { return false }
                for (a, b) in zip(path, path.dropFirst()) {
                    if h.call("edge_clear", [a, b, tracks, .vec(0, 0, 3000), .vec(0, 0, 100)])?.truthy != true { return false }
                }
                return true
            }),
            ("test_budget_per_tick", { h in
                let rocks = (0..<40).map { i -> Value in
                    .tuple([.vec(Double(i % 7) * 30 - 90, Double(i % 5) * 30 - 60, Double(i) * 200 + 50), .vec(5, -3, -100), .float(5)])
                }
                h.values["radar_tracks"] = .list(ListRef(rocks))
                h.values["position"] = .vec(0, 0, 3000); h.values["velocity"] = .vec(0, 0, 100)
                return h.call("update", [.float(0.02)]) != nil
            }),
        ],
    ]
}
