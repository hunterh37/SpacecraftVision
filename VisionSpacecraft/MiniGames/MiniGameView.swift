import SwiftUI
import Curriculum

/// Concept-stage mini game for a lesson (specs/06 catalog, specs/16 `mini.*`). Play by hand, or press
/// "Watch the rule" to see the lesson's rule do it.
struct MiniGameView: View {
    let lesson: Int
    var body: some View {
        if let kind = MiniGameKind.forLesson(lesson) {
            VStack(alignment: .leading, spacing: 8) {
                Text(kind.title).font(.headline)
                Text(kind.rules).font(.caption).foregroundStyle(.secondary)
                Group {
                    switch kind {
                    case .stairs: StairsGame()
                    case .balance: BalanceGame()
                    case .cart: CartGame()
                    case .handSteer: HandSteerGame()
                    case .marble: MarbleGame()
                    case .polarBars: PolarBarsGame()
                    case .cones: ConesGame()
                    case .flood: FloodGame()
                    case .tree: TreeGame()
                    }
                }
                .frame(height: 220)
            }
            .id(lesson)
        }
    }
}

private struct ResultLine: View {
    let won: Bool, lost: Bool, auto: Bool
    var body: some View {
        Text(won ? MiniCopy.pass : lost ? MiniCopy.retry : auto ? MiniCopy.auto : " ")
            .font(.callout.bold()).foregroundStyle(won ? .green : lost ? .orange : .secondary)
    }
}

/// Fixed 50 Hz driver for the continuous games.
private struct Ticker: ViewModifier {
    let running: Bool
    let tick: () -> Void
    func body(content: Content) -> some View {
        content.task(id: running) {
            while running && !Task.isCancelled {
                tick()
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
    }
}

private extension View {
    func ticking(_ running: Bool, _ tick: @escaping () -> Void) -> some View { modifier(Ticker(running: running, tick: tick)) }
}

// MARK: 0

private struct StairsGame: View {
    @State private var g = ThrottleStairs()
    @State private var auto = false
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(ThrottleStairs.steps.indices, id: \.self) { i in
                    Button { g.tap(step: i) } label: {
                        Rectangle().fill(.tint.opacity(0.6)).frame(width: 22, height: 20 + CGFloat(i) * 12)
                    }.buttonStyle(.plain)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    ForEach(Array(g.tries.enumerated()), id: \.offset) { _, a in
                        Text("\(Int(a)) m").foregroundStyle(g.band.contains(a) ? .green : .primary)
                    }
                    Text("Band \(Int(g.band.lowerBound))–\(Int(g.band.upperBound)) m").font(.caption)
                }
            }
            HStack {
                Button("Watch the rule") { g = ThrottleStairs(); auto = true; g.tap(step: ThrottleStairs.ruleStep) }
                Button("Reset") { g = ThrottleStairs(); auto = false }
                ResultLine(won: g.won, lost: g.lost, auto: auto)
            }
        }
    }
}

// MARK: 1

private struct BalanceGame: View {
    @State private var g = BalanceStick()
    @State private var input = 0.0
    @State private var auto = false
    @State private var running = false
    var body: some View {
        VStack {
            Canvas { ctx, size in
                let base = CGPoint(x: size.width / 2, y: size.height - 10)
                let tip = CGPoint(x: base.x + sin(g.angle) * 120, y: base.y - cos(g.angle) * 120)
                var p = Path(); p.move(to: base); p.addLine(to: tip)
                ctx.stroke(p, with: .color(abs(g.angle) < 0.1745 ? .green : .orange), lineWidth: 6)
            }
            .gesture(DragGesture(minimumDistance: 0).onChanged { input = max(-1, min(1, $0.translation.width / 80)) }.onEnded { _ in input = 0 })
            HStack {
                Text(String(format: "Held %.1f / 20 s", g.held)).monospacedDigit()
                if auto { Slider(value: $g.gain, in: 0...60).frame(width: 120) }
                Button(running ? "Stop" : "Start") { if g.fallen || g.won { g = BalanceStick() }; running.toggle() }
                Button("Watch the rule") { g = BalanceStick(); g.gain = 40; auto = true; running = true }
                ResultLine(won: g.won, lost: g.fallen, auto: auto)
            }
        }
        .ticking(running && !g.won && !g.fallen) { g.step(dt: 0.02, input: input, auto: auto) }
    }
}

// MARK: 2

private struct CartGame: View {
    @State private var c = CartPID()
    @State private var run: CartPID.Run?
    @State private var auto = false
    var body: some View {
        VStack {
            Canvas { ctx, size in
                var line = Path(); line.move(to: CGPoint(x: 0, y: size.height / 2)); line.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                ctx.stroke(line, with: .color(.secondary), lineWidth: 1)
                guard let r = run else { return }
                var p = Path()
                for (i, x) in r.trace.enumerated() {
                    let pt = CGPoint(x: CGFloat(i) / 250 * size.width, y: size.height / 2 - CGFloat(max(-2, min(2, x))) * size.height / 4)
                    i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                }
                ctx.stroke(p, with: .color(.accentColor), lineWidth: 2)
            }
            HStack {
                dial("P", $c.kp); dial("I", $c.ki); dial("D", $c.kd)
                Button("Release") { run = c.release() }
                Button("Watch the rule") { c = CartPID.rule; auto = true; run = c.release() }
                ResultLine(won: run.map { $0.settled && $0.crossings <= 1 } ?? false,
                           lost: run.map { !($0.settled && $0.crossings <= 1) } ?? false, auto: auto)
            }
        }
    }
    func dial(_ n: String, _ v: Binding<Double>) -> some View {
        HStack(spacing: 2) { Text(n); Slider(value: v, in: 0...8).frame(width: 70) }
    }
}

// MARK: 3, 4

private struct HandSteerGame: View {
    @State private var g = HandSteer()
    @State private var steer = 0.0
    @State private var auto = false
    @State private var running = false
    var body: some View {
        VStack {
            Canvas { ctx, size in
                let s = min(size.width, size.height) / 21
                func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: size.width / 2 + x * s, y: size.height / 2 - y * s) }
                for b in g.blocks {
                    ctx.fill(Path(ellipseIn: CGRect(x: pt(b.x, b.y).x - b.r * s, y: pt(b.x, b.y).y - b.r * s, width: 2 * b.r * s, height: 2 * b.r * s)), with: .color(.gray))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: pt(0, 9).x - 0.8 * s, y: pt(0, 9).y - 0.8 * s, width: 1.6 * s, height: 1.6 * s)), with: .color(.green.opacity(0.5)))
                ctx.fill(Path(ellipseIn: CGRect(x: pt(g.x, g.y).x - 5, y: pt(g.x, g.y).y - 5, width: 10, height: 10)), with: .color(.accentColor))
            }
            .gesture(DragGesture(minimumDistance: 0).onChanged { steer = max(-1, min(1, $0.translation.width / 60)) }.onEnded { _ in steer = 0 })
            HStack {
                Text("Home \(g.roversHome) / 3")
                Button(running ? "Stop" : "Go") { running.toggle() }
                Button("Watch the rule") { g = HandSteer(round: 1); auto = true; running = true }
                ResultLine(won: g.won, lost: false, auto: auto)
            }
        }
        .ticking(running && !g.won) { g.step(dt: 0.02, steer: auto ? g.bugSteer() : steer) }
    }
}

// MARK: 5

private struct MarbleGame: View {
    @State private var m = Marble()
    @State private var running = false
    @State private var auto = false
    var body: some View {
        VStack {
            GeometryReader { geo in
                let s: CGFloat = min(geo.size.width, geo.size.height) / 20
                Canvas { ctx, size in
                    func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: size.width / 2 + CGFloat(x) * s, y: size.height / 2 - CGFloat(y) * s) }
                    func dot(_ c: CGPoint, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)) }
                    for h in m.hills { ctx.fill(dot(pt(h.x, h.y), s), with: .color(.brown.opacity(0.6))) }
                    ctx.fill(dot(pt(0, 8), 8), with: .color(.green.opacity(0.5)))
                    ctx.fill(dot(pt(m.x, m.y), 6), with: .color(.accentColor))
                }
                .contentShape(Rectangle())
                .onTapGesture { p in m.place(.init(x: (p.x - geo.size.width / 2) / s, y: (geo.size.height / 2 - p.y) / s)) }
            }
            HStack {
                Button("Roll") { m.restart(); running = true }
                Button("Clear") { m = Marble(); running = false }
                Button("Watch the rule") { m = Marble(); for h in Marble.trapPlacement { m.place(h) }; auto = true; running = true }
                ResultLine(won: m.won, lost: m.atGoal, auto: auto)
            }
        }
        .ticking(running && !m.won && !m.atGoal) { m.step(dt: 0.02) }
    }
}

// MARK: 6

private struct PolarBarsGame: View {
    @State private var p = PolarBars()
    @State private var picked: Int?
    @State private var auto = false
    var body: some View {
        VStack {
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2), r0 = 30.0
                Canvas { ctx, _ in
                    for s in 0..<PolarBars.sectors {
                        let a = Double(s) * 10 * .pi / 180
                        let len = r0 + p.bars[s] * 70
                        var path = Path()
                        path.move(to: CGPoint(x: c.x + sin(a) * r0, y: c.y - cos(a) * r0))
                        path.addLine(to: CGPoint(x: c.x + sin(a) * len, y: c.y - cos(a) * len))
                        ctx.stroke(path, with: .color(s == picked ? .green : p.bars[s] < p.threshold ? .accentColor : .gray), lineWidth: 6)
                    }
                    let tr = r0 + p.threshold * 70
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - tr, y: c.y - tr, width: 2 * tr, height: 2 * tr)), with: .color(.orange), lineWidth: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture { t in
                    let a = atan2(t.x - c.x, c.y - t.y)
                    picked = (Int((a * 180 / .pi / 10).rounded()) + 36) % 36
                }
            }
            HStack {
                Text("Threshold"); Slider(value: $p.threshold, in: 0.1...1).frame(width: 120)
                Button("Watch the rule") { auto = true; picked = p.ruleSector }
                ResultLine(won: picked.map { p.accepts($0) } ?? false, lost: picked.map { !p.accepts($0) } ?? false, auto: auto)
            }
        }
    }
}

// MARK: 7

private struct ConesGame: View {
    @State private var c = Cones()
    @State private var v = CGPoint(x: 0, y: 3)
    @State private var missed = false
    @State private var auto = false
    var body: some View {
        VStack {
            GeometryReader { geo in
                let o = CGPoint(x: geo.size.width / 2, y: geo.size.height - 20), s = 12.0
                Canvas { ctx, _ in
                    for d in c.debris {
                        let p = CGPoint(x: o.x + d.px * s, y: o.y - d.py * s)
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - d.r * s, y: p.y - d.r * s, width: 2 * d.r * s, height: 2 * d.r * s)), with: .color(.gray))
                    }
                    var a = Path(); a.move(to: o); a.addLine(to: CGPoint(x: o.x + v.x * s * 2, y: o.y - v.y * s * 2))
                    ctx.stroke(a, with: .color(c.safe(v.x, v.y) ? .green : .red), lineWidth: 3)
                }
                .gesture(DragGesture(minimumDistance: 0).onChanged { t in
                    v = CGPoint(x: (t.location.x - o.x) / (2 * s), y: (o.y - t.location.y) / (2 * s))
                })
            }
            HStack {
                Text("Wave \(min(c.wave + 1, 3)) / 3")
                Button("Commit") { missed = !c.commit(v.x, v.y) }
                Button("Watch the rule") { auto = true; c = Cones(); for _ in 0..<3 { let r = c.ruleVelocity(); v = CGPoint(x: r.0, y: r.1); c.commit(r.0, r.1) } }
                ResultLine(won: c.won, lost: missed, auto: auto)
            }
        }
    }
}

// MARK: 8

private struct FloodGame: View {
    @State private var f = FloodTiles()
    @State private var auto = false
    @State private var tried = false
    var body: some View {
        VStack {
            GeometryReader { geo in
                let cw = geo.size.width / CGFloat(f.w), ch = geo.size.height / CGFloat(f.h)
                Canvas { ctx, _ in
                    for i in 0..<(f.w * f.h) {
                        let r = CGRect(x: CGFloat(i % f.w) * cw, y: CGFloat(i / f.w) * ch, width: cw - 1, height: ch - 1)
                        let color: Color = i == f.start || i == f.goal ? .green : f.walls.contains(i) ? .gray :
                            f.path.contains(i) ? .accentColor : f.expanded.contains(i) ? .orange.opacity(0.4) : .secondary.opacity(0.15)
                        ctx.fill(Path(r), with: .color(color))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { p in f.toggle(Int(p.y / ch) * f.w + Int(p.x / cw)); tried = false }
            }
            HStack {
                Text("Expanded \(f.expanded.count)")
                Button("Flood") { f.flood(); tried = true }
                Button("Watch the rule") { auto = true; f.flood(); tried = true }
                ResultLine(won: f.won, lost: tried && !f.won, auto: auto)
            }
        }
    }
}

// MARK: 9

private struct TreeGame: View {
    @State private var t = GrowingTree()
    @State private var auto = false
    var body: some View {
        VStack {
            GeometryReader { geo in
                let s: CGFloat = geo.size.height / 11
                let w: CGFloat = geo.size.width, hgt: CGFloat = geo.size.height
                Canvas { ctx, _ in
                    func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: w / 2 + CGFloat(x) * s, y: hgt - CGFloat(y) * s) }
                    for b in t.blocks { ctx.fill(Path(ellipseIn: CGRect(x: pt(b.x, b.y).x - b.r * s, y: pt(b.x, b.y).y - b.r * s, width: 2 * b.r * s, height: 2 * b.r * s)), with: .color(.gray)) }
                    for n in t.nodes { if let p = n.parent { var l = Path(); l.move(to: pt(t.nodes[p].x, t.nodes[p].y)); l.addLine(to: pt(n.x, n.y)); ctx.stroke(l, with: .color(.green), lineWidth: 2) } }
                    var top = Path(); top.move(to: pt(-6, t.top)); top.addLine(to: pt(6, t.top)); ctx.stroke(top, with: .color(.orange), lineWidth: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture { p in t.sample((p.x - geo.size.width / 2) / s, (geo.size.height - p.y) / s) }
            }
            HStack {
                Text("Samples \(t.samples) / 30")
                Button("Reset") { t = GrowingTree(); auto = false }
                Button("Watch the rule") { auto = true; t = GrowingTree.autoPlay() }
                ResultLine(won: t.won, lost: t.outOfSamples, auto: auto)
            }
        }
    }
}
