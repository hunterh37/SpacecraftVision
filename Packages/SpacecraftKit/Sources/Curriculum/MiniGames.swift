import Foundation

/// Concept-stage mini games (specs/06 catalog, copy in specs/16 `mini.*`). Pure state machines: views feed input,
/// call `step`, and read `won`. Each has an auto-play that runs the lesson's rule ("Watch the rule run.").
public enum MiniGameKind: String, CaseIterable, Sendable {
    case stairs, balance, cart, handSteer, marble, polarBars, cones, flood, tree

    public static func forLesson(_ id: Int) -> MiniGameKind? {
        switch id {
        case 0: .stairs; case 1: .balance; case 2: .cart; case 3, 4: .handSteer; case 5: .marble; case 6: .polarBars
        case 7: .cones; case 8: .flood; case 9: .tree
        default: nil
        }
    }

    public var title: String {
        switch self {
        case .stairs: "Throttle stairs"; case .balance: "Balance stick"; case .cart: "Steer the cart"
        case .handSteer: "Hand steering"; case .marble: "Marble on a slope"; case .polarBars: "Polar bars"
        case .cones: "Cones of collision"; case .flood: "Flood tiles"; case .tree: "Growing tree"
        }
    }

    public var rules: String {
        switch self {
        case .stairs: "Tap a step to set the phase. Reach the target height band on the wall chart within 3 tries."
        case .balance: "Move left or right to keep the stick within 10 deg of vertical for 20 s while gusts push it. A gain dial replaces your hand in round 2."
        case .cart: "Set the P, I and D dials, then release the cart. Settle on the line within 5 s without crossing it more than once."
        case .handSteer: "Steer the rover left or right around blocks to its home pad. Get 3 rovers home. Round 2 plays the Bug rule for comparison."
        case .marble: "Place obstacle hills on a sloped table; the marble rolls to the goal. Find one placement that traps it."
        case .polarBars: "Bars around the craft show crowding. Drag the threshold line, then pick a heading through a gap at least 3 sectors wide."
        case .cones: "Drag the velocity arrow so its tip sits outside every cone for 3 waves of debris."
        case .flood: "Tap tiles to place walls; press Flood to watch A* expand. Reach the goal with the fewest expanded tiles."
        case .tree: "Drop sample points; the tree extends toward each. Reach the top of the volume in 30 samples or fewer."
        }
    }
}

public enum MiniCopy {
    public static let pass = "Done.", retry = "Try again.", auto = "Watch the rule run."
}

public struct MiniRNG: Sendable {
    var s: UInt64
    public init(_ seed: UInt64) { s = seed }
    public mutating func unit() -> Double {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}

// MARK: Lesson 0: throttle stairs

/// Pick the cutoff step; the hop's apogee follows the lesson's reference ratio (cutoff 360 m gives 1,092 m).
public struct ThrottleStairs: Sendable {
    public static let steps: [Double] = stride(from: 150.0, through: 600.0, by: 50).map { $0 }
    public let band: ClosedRange<Double> = 1000...1200
    public private(set) var tries: [Double] = []
    public init() {}
    public static func apogee(cutoff: Double) -> Double { cutoff * 1092 / 360 }
    public var won: Bool { tries.contains { band.contains($0) } }
    public var lost: Bool { !won && tries.count >= 3 }
    @discardableResult public mutating func tap(step i: Int) -> Double {
        guard !won, !lost, Self.steps.indices.contains(i) else { return tries.last ?? 0 }
        let a = Self.apogee(cutoff: Self.steps[i]); tries.append(a); return a
    }
    /// The rule: cut off at the altitude whose coast reaches the middle of the band.
    public static var ruleStep: Int { steps.indices.min { abs(apogee(cutoff: steps[$0]) - 1100) < abs(apogee(cutoff: steps[$1]) - 1100) }! }
}

// MARK: Lesson 1: balance stick

public struct BalanceStick: Sendable {
    public private(set) var angle = 0.05, rate = 0.0, held = 0.0, time = 0.0
    public var gain = 0.0
    var rng: MiniRNG
    public init(seed: UInt64 = 1) { rng = MiniRNG(seed) }
    public var won: Bool { held >= 20 }
    public var fallen: Bool { abs(angle) > .pi / 2 }
    /// input -1...1 pushes the base; with `auto` the gain dial does it (P on angle, D on rate).
    public mutating func step(dt: Double, input: Double, auto: Bool = false) {
        guard !won, !fallen else { return }
        let gust = (rng.unit() - 0.5) * 1.2
        let u = auto ? -(gain * angle + 0.35 * gain * rate) : input * 12
        rate += (9.81 * sin(angle) + u + gust) * dt
        angle += rate * dt
        time += dt
        held = abs(angle) < 10 * .pi / 180 ? held + dt : 0
    }
}

// MARK: Lesson 2: steer the cart (PID)

public struct CartPID: Sendable {
    public var kp = 0.0, ki = 0.0, kd = 0.0
    public init() {}
    public struct Run: Sendable { public var trace: [Double]; public var crossings: Int; public var settled: Bool }
    /// Release the cart 1 m off the line with a constant drift; 5 s at 50 Hz.
    public func release() -> Run {
        var x = 1.0, v = 0.0, integral = 0.0, prev = x, crossings = 0
        var trace: [Double] = []
        let dt = 0.02
        for k in 0..<250 {
            let e = -x
            integral += e * dt
            let d = k == 0 ? 0 : (e - (-prev)) / dt
            prev = x
            let a = kp * e + ki * integral + kd * d + 0.4   // 0.4 m/s² side wind
            v += a * dt; x += v * dt
            if (prev > 0) != (x > 0) { crossings += 1 }
            trace.append(x)
        }
        let settled = trace.suffix(25).allSatisfy { abs($0) < 0.05 }
        return Run(trace: trace, crossings: crossings, settled: settled)
    }
    public var won: Bool { let r = release(); return r.settled && r.crossings <= 1 }
    public static let rule: CartPID = { var c = CartPID(); c.kp = 4; c.ki = 2; c.kd = 3; return c }()
}

// MARK: Lessons 3 and 4: hand steering (Bug)

public struct HandSteer: Sendable {
    public struct Block: Sendable { public var x, y, r: Double }
    public var blocks: [Block]
    public let home = (x: 0.0, y: 9.0)
    public private(set) var x = 0.0, y = -9.0, heading = 0.0
    public private(set) var roversHome = 0, crashes = 0
    var bugTurning = 0.0
    public init(round: Int = 0) {
        blocks = [Block(x: 0, y: -2, r: 2.2), Block(x: -3.5, y: 4, r: 1.5), Block(x: 3, y: 3, r: 1.4)]
        if round % 2 == 1 { blocks[0].x = 0.8 }
    }
    public var won: Bool { roversHome >= 3 }
    mutating func reset() { x = 0; y = -9; heading = 0; bugTurning = 0 }
    func clear(_ px: Double, _ py: Double) -> Double {
        blocks.map { hypot(px - $0.x, py - $0.y) - $0.r }.min() ?? 99
    }
    /// steer -1 (left) ... 1 (right); heading 0 = +y.
    public mutating func step(dt: Double, steer: Double) {
        guard !won else { return }
        heading += max(-1, min(1, steer)) * 1.6 * dt
        x += sin(heading) * 2.5 * dt; y += cos(heading) * 2.5 * dt
        if clear(x, y) < 0.3 || abs(x) > 10 || y < -10 || y > 10.5 { crashes += 1; reset() }
        if hypot(x - home.x, y - home.y) < 0.8 { roversHome += 1; reset() }
    }
    /// Bug 0: head home; when something is close ahead, turn toward the open side until the way home is clear.
    public func bugSteer() -> Double {
        let goal = atan2(home.x - x, home.y - y)
        var err = goal - heading
        while err > .pi { err -= 2 * .pi }; while err < -.pi { err += 2 * .pi }
        func probe(_ a: Double, _ d: Double) -> Double { clear(x + sin(a) * d, y + cos(a) * d) }
        if probe(goal, 2.0) < 0.6 || probe(heading, 1.8) < 0.5 {
            return probe(heading + 0.6, 2) > probe(heading - 0.6, 2) ? 1 : -1
        }
        return max(-1, min(1, 2 * err))
    }
}

// MARK: Lesson 5: marble on a slope (potential field)

public struct Marble: Sendable {
    public struct Hill: Sendable { public var x, y: Double }
    public var hills: [Hill] = []
    public let goal = (x: 0.0, y: 8.0)
    public private(set) var x = 0.0, y = -8.0, vx = 0.0, vy = 0.0, stillTime = 0.0, time = 0.0
    public init() {}
    public var atGoal: Bool { hypot(x - goal.x, y - goal.y) < 0.6 }
    /// Win: the player found a placement that traps the marble away from the goal.
    public var trapped: Bool { stillTime > 2 && !atGoal }
    public var won: Bool { trapped }
    public mutating func place(_ h: Hill) { if hills.count < 6 { hills.append(h) } }
    public mutating func restart() { x = 0; y = -8; vx = 0; vy = 0; stillTime = 0; time = 0 }
    public func force(_ px: Double, _ py: Double) -> (Double, Double) {
        let dx = goal.x - px, dy = goal.y - py, d = max(hypot(dx, dy), 0.1)
        var fx = dx / d, fy = dy / d
        for h in hills {
            let hx = px - h.x, hy = py - h.y, r = max(hypot(hx, hy), 0.2)
            if r < 3 { let m = 3.0 * (1 / r - 1 / 3) / (r * r); fx += m * hx / r; fy += m * hy / r }
        }
        return (fx, fy)
    }
    public mutating func step(dt: Double) {
        guard !atGoal, !trapped else { return }
        let (fx, fy) = force(x, y)
        vx = (vx + fx * 3 * dt) * 0.9; vy = (vy + fy * 3 * dt) * 0.9
        x += vx * dt; y += vy * dt; time += dt
        stillTime = hypot(vx, vy) < 0.05 ? stillTime + dt : 0
    }
    /// A placement that traps the marble: a hill straight ahead on the line to the goal, flanked by two more.
    public static let trapPlacement: [Hill] = [Hill(x: 0, y: 2), Hill(x: -1.6, y: 0.8), Hill(x: 1.6, y: 0.8)]
}

// MARK: Lesson 6: polar bars (VFH)

public struct PolarBars: Sendable {
    public static let sectors = 36
    public var bars: [Double]
    public var threshold = 0.5
    public let goalSector = 0
    public init(seed: UInt64 = 6) {
        var r = MiniRNG(seed)
        bars = (0..<Self.sectors).map { _ in r.unit() * 0.4 }
        for s in [34, 35, 0, 1, 2, 9, 10, 11, 20, 21, 27, 28] { bars[s] = 0.7 + r.unit() * 0.3 }
    }
    /// Valley: run of consecutive sectors under the threshold containing `s`.
    public func valleyWidth(at s: Int) -> Int {
        guard bars[(s + Self.sectors) % Self.sectors] < threshold else { return 0 }
        var w = 1, i = s + 1
        while w < Self.sectors && bars[(i + Self.sectors) % Self.sectors] < threshold { w += 1; i += 1 }
        i = s - 1
        while w < Self.sectors && bars[(i + Self.sectors) % Self.sectors] < threshold { w += 1; i -= 1 }
        return w
    }
    public func accepts(_ s: Int) -> Bool { valleyWidth(at: s) >= 3 }
    /// The rule: the sector in a wide-enough valley closest to the goal.
    public var ruleSector: Int? {
        (0..<Self.sectors).filter { accepts($0) }.min {
            let a = min(abs($0 - goalSector), Self.sectors - abs($0 - goalSector))
            let b = min(abs($1 - goalSector), Self.sectors - abs($1 - goalSector))
            return a < b
        }
    }
}

// MARK: Lesson 7: cones of collision (velocity obstacles)

public struct Cones: Sendable {
    public struct Debris: Sendable { public var px, py, vx, vy, r: Double }
    public private(set) var wave = 0
    public private(set) var debris: [Debris] = []
    var rng: MiniRNG
    public init(seed: UInt64 = 7) { rng = MiniRNG(seed); spawn() }
    public var won: Bool { wave >= 3 }
    mutating func spawn() {
        debris = (0..<3).map { _ in
            Debris(px: rng.unit() * 16 - 8, py: 6 + rng.unit() * 6, vx: rng.unit() * 2 - 1, vy: -1 - rng.unit() * 2, r: 0.8 + rng.unit() * 0.6)
        }
    }
    /// True when velocity (vx, vy) never comes within r of any debris over 8 s.
    public func safe(_ vx: Double, _ vy: Double) -> Bool {
        debris.allSatisfy { d in
            let rx = d.px, ry = d.py, ux = d.vx - vx, uy = d.vy - vy
            let uu = ux * ux + uy * uy
            let t = uu > 0 ? max(0, min(8, -(rx * ux + ry * uy) / uu)) : 0
            return hypot(rx + ux * t, ry + uy * t) > d.r + 0.5
        }
    }
    /// Commit the arrow for this wave. Returns true when the tip sat outside every cone.
    @discardableResult public mutating func commit(_ vx: Double, _ vy: Double) -> Bool {
        guard !won else { return true }
        let ok = safe(vx, vy)
        if ok { wave += 1; if !won { spawn() } }
        return ok
    }
    /// The rule: the safe candidate on a grid nearest to straight up at 3 m/s.
    public func ruleVelocity() -> (Double, Double) {
        var best = (0.0, 0.0), cost = Double.infinity
        for ix in -8...8 { for iy in -8...8 {
            let vx = Double(ix) * 0.5, vy = Double(iy) * 0.5
            guard safe(vx, vy) else { continue }
            let c = hypot(vx, vy - 3)
            if c < cost { cost = c; best = (vx, vy) }
        } }
        return best
    }
}

// MARK: Lesson 8: flood tiles (A*)

public struct FloodTiles: Sendable {
    public let w = 12, h = 9
    public var walls: Set<Int> = []
    public let start = 4 * 12        // row 4, col 0
    public let goal = 4 * 12 + 11
    public private(set) var expanded: [Int] = []
    public private(set) var path: [Int] = []
    public init() {}
    public mutating func toggle(_ i: Int) {
        guard i != start, i != goal, (0..<(w * h)).contains(i) else { return }
        if walls.contains(i) { walls.remove(i) } else { walls.insert(i) }
        expanded = []; path = []
    }
    /// Run A* (4-connected, Manhattan heuristic). Returns true when the goal is reached.
    @discardableResult public mutating func flood() -> Bool {
        let s = 4 * w
        func hcost(_ i: Int) -> Int { abs(i % w - goal % w) + abs(i / w - goal / w) }
        var open: Set<Int> = [s], g: [Int: Int] = [s: 0], came: [Int: Int] = [:], closed: Set<Int> = []
        expanded = []
        while let cur = open.min(by: { (g[$0]! + hcost($0), hcost($0)) < (g[$1]! + hcost($1), hcost($1)) }) {
            open.remove(cur); closed.insert(cur); expanded.append(cur)
            if cur == goal {
                var p = [cur]; var c = cur
                while let n = came[c] { p.append(n); c = n }
                path = p.reversed(); return true
            }
            let x = cur % w, y = cur / w
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                let n = ny * w + nx
                guard !walls.contains(n), !closed.contains(n) else { continue }
                let ng = g[cur]! + 1
                if ng < g[n, default: .max] { g[n] = ng; came[n] = cur; open.insert(n) }
            }
        }
        path = []; return false
    }
    public var won: Bool { !path.isEmpty }
}

// MARK: Lesson 9: growing tree (RRT)

public struct GrowingTree: Sendable {
    public struct Node: Sendable { public var x, y: Double; public var parent: Int? }
    public private(set) var nodes: [Node] = [Node(x: 0, y: 0, parent: nil)]
    public private(set) var samples = 0
    public let step = 1.2, top = 10.0
    public let blocks: [(x: Double, y: Double, r: Double)] = [(-2, 4, 1.5), (2.5, 6.5, 1.4), (0, 8, 1)]
    public init() {}
    public var won: Bool { nodes.contains { $0.y >= top } && samples <= 30 }
    public var outOfSamples: Bool { samples >= 30 && !won }
    /// Drop a sample; the nearest node extends one step toward it unless a block is in the way.
    public mutating func sample(_ sx: Double, _ sy: Double) {
        guard !won, samples < 30 else { return }
        samples += 1
        let i = nodes.indices.min { hypot(nodes[$0].x - sx, nodes[$0].y - sy) < hypot(nodes[$1].x - sx, nodes[$1].y - sy) }!
        let n = nodes[i], d = max(hypot(sx - n.x, sy - n.y), 1e-6), s = min(step, d)
        let nx = n.x + (sx - n.x) / d * s, ny = n.y + (sy - n.y) / d * s
        guard blocks.allSatisfy({ hypot(nx - $0.x, ny - $0.y) > $0.r }) else { return }
        nodes.append(Node(x: nx, y: ny, parent: i))
    }
    /// The rule: random samples with a 50% bias toward the top.
    public static func autoPlay(seed: UInt64 = 9) -> GrowingTree {
        var t = GrowingTree(), r = MiniRNG(seed)
        while !t.won && t.samples < 30 {
            if r.unit() < 0.5 { t.sample(r.unit() * 6 - 3, 11) } else { t.sample(r.unit() * 10 - 5, r.unit() * 11) }
        }
        return t
    }
}
