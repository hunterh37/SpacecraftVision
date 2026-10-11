import SwiftUI
import simd
import SpacecraftCore
import FlightSim
import FlightRunner

/// The real rocket as the simulator has flown it so far, for the live marker.
public struct FlightLive: Sendable {
    public var samples: [FlightSample]
    public var running: Bool
    public init(samples: [FlightSample], running: Bool) { self.samples = samples; self.running = running }
}

/// The flight drawn from the simulator's own 50 Hz samples: predicted path coloured by speed, sim events as pins,
/// the rocket at the cursor (position and attitude from the sample), and, while a launch runs, the real rocket on top.
/// Dragging the graph or the time strip moves `cursor`; the trace follows it.
public struct FlightPathView: View {
    public var report: FlightReport?
    public var course: Course
    public var live: FlightLive?
    @Binding public var cursor: Double
    public var height: CGFloat
    public var onScrubEnd: () -> Void

    public init(report: FlightReport?, course: Course, live: FlightLive? = nil, cursor: Binding<Double>, height: CGFloat = 170, onScrubEnd: @escaping () -> Void = {}) {
        self.report = report; self.course = course; self.live = live; _cursor = cursor; self.height = height; self.onScrubEnd = onScrubEnd
    }

    private var samples: [FlightSample] { report?.samples ?? [] }
    private var events: [PathEvent] { PathEvent.parse(report?.events ?? []) }
    private var duration: Double { samples.last?.t ?? 1 }
    private var maxSpeed: Double { max(samples.map(\.speed).max() ?? 1, 1) }

    private func speedColor(_ f: Double) -> Color {
        f < 0.5 ? mix(Brand.telemetry, Brand.trajectory, f * 2) : mix(Brand.trajectory, Brand.ignition, (f - 0.5) * 2)
    }
    private func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        #if canImport(UIKit)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, o: CGFloat = 0
        UIColor(a).getRed(&ar, green: &ag, blue: &ab, alpha: &o); UIColor(b).getRed(&br, green: &bg, blue: &bb, alpha: &o)
        return Color(red: ar + (br - ar) * t, green: ag + (bg - ag) * t, blue: ab + (bb - ab) * t)
        #else
        return t < 0.5 ? a : b
        #endif
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if samples.isEmpty {
                Text(report == nil ? "No flight to draw yet." : "The code does not fly yet, so there is no path.").font(Lab.soft(13)).foregroundStyle(Lab.muted)
                    .frame(maxWidth: .infinity, minHeight: height, alignment: .center)
            } else {
                graph.frame(height: height)
                strip.frame(height: 46)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Brand.telemetry).frame(width: 22, height: 3).clipShape(Capsule())
            Text("REAL FLIGHT PATH").font(Brand.label(11)).tracking(2).foregroundStyle(Brand.telemetry)
            Spacer()
            if let r = report?.result, !samples.isEmpty {
                stat("APOGEE", "\(Int(r.apogee)) m"); stat("MAX SPEED", "\(Int(maxSpeed)) m/s"); stat("TIME", String(format: "%.0f s", r.duration))
            }
            LinearGradient(colors: [Brand.telemetry, Brand.trajectory, Brand.ignition], startPoint: .leading, endPoint: .trailing)
                .frame(width: 60, height: 5).clipShape(Capsule()).overlay(alignment: .bottom) { Text("slow  fast").font(Lab.mono(8)).foregroundStyle(Lab.faint).offset(y: 11) }
                .padding(.bottom, 8)
        }
    }

    private func stat(_ k: String, _ v: String) -> some View {
        HStack(spacing: 4) { Text(k).foregroundStyle(Lab.faint); Text(v).foregroundStyle(Lab.ink).fontWeight(.semibold) }.font(Lab.mono(10.5))
    }

    // MARK: graph

    private var graph: some View {
        GeometryReader { geo in
            let size = geo.size
            let proj = PathProjection(samples: samples + (live?.samples ?? []), course: course)
            Canvas { ctx, size in draw(ctx, size, proj) }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { g in if let i = proj.nearest(samples, to: g.location, in: size) { cursor = samples[i].t } }
                    .onEnded { _ in onScrubEnd() })
        }
        .background(Color(red: 0.02, green: 0.03, blue: 0.1).opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Lab.edge.opacity(0.22), lineWidth: 1) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ proj: PathProjection) {
        var ctx = ctx
        let sc = proj.scale(in: size)
        func P(_ v: Vec3) -> CGPoint { proj.point(v, in: size) }

        // measuring dots
        var dots = Path(); var gy: CGFloat = 12
        while gy < size.height { var gx: CGFloat = 12; while gx < size.width { dots.addEllipse(in: CGRect(x: gx, y: gy, width: 1.4, height: 1.4)); gx += 24 }; gy += 24 }
        ctx.fill(dots, with: .color(Lab.edge.opacity(0.14)))

        // ground and altitude ticks (side profile)
        if proj.mode == .side {
            let g0 = P(Vec3(0, 0, 0)).y
            var ground = Path(); ground.move(to: CGPoint(x: 0, y: g0)); ground.addLine(to: CGPoint(x: size.width, y: g0))
            ctx.stroke(ground, with: .color(Lab.edge.opacity(0.35)), lineWidth: 1)
            let top = proj.maxV, step = [100.0, 200, 250, 500, 1000, 2000].first { top / $0 <= 5 } ?? 2000
            var a = step
            while a < top {
                let y = P(Vec3(0, 0, a)).y
                var t = Path(); t.move(to: CGPoint(x: 0, y: y)); t.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(t, with: .color(Lab.edge.opacity(0.09)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                ctx.draw(Text("\(Int(a)) m").font(Lab.mono(9)).foregroundStyle(Lab.faint), at: CGPoint(x: 6, y: y - 7), anchor: .leading)
                a += step
            }
        }

        // corridor, landing zone, gates, goal
        drawCourse(&ctx, proj, size, sc)

        // predicted path, coloured by speed
        let vmax = maxSpeed
        if samples.count > 1 {
            let stride = max(1, samples.count / 700)
            var i = stride
            while i < samples.count {
                var seg = Path(); seg.move(to: P(samples[i - stride].position)); seg.addLine(to: P(samples[i].position))
                let c = speedColor(min(1, samples[i].speed / vmax))
                ctx.stroke(seg, with: .color(c.opacity(0.95)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                i += stride
            }
        }

        // events
        var labelled: [CGPoint] = []
        for e in events {
            guard let i = samples.index(atTime: e.time) else { continue }
            let p = P(samples[i].position)
            var d = Path(); d.move(to: CGPoint(x: p.x, y: p.y - 5)); d.addLine(to: CGPoint(x: p.x + 5, y: p.y)); d.addLine(to: CGPoint(x: p.x, y: p.y + 5)); d.addLine(to: CGPoint(x: p.x - 5, y: p.y)); d.closeSubpath()
            ctx.fill(d, with: .color(Brand.ignition)); ctx.stroke(d, with: .color(.white.opacity(0.8)), lineWidth: 1)
            if !labelled.contains(where: { hypot($0.x - p.x, $0.y - p.y) < 38 }) {
                labelled.append(p)
                let label = e.text.count > 22 ? String(e.text.prefix(21)) + "..." : e.text
                ctx.draw(Text(label).font(Lab.mono(9.5)).foregroundStyle(Lab.muted), at: CGPoint(x: p.x + 9, y: p.y - 8), anchor: .leading)
            }
        }

        // failure
        if let f = report?.result.failure, let i = samples.index(atTime: f.time) {
            let p = P(samples[i].position)
            var x = Path(); x.move(to: CGPoint(x: p.x - 6, y: p.y - 6)); x.addLine(to: CGPoint(x: p.x + 6, y: p.y + 6)); x.move(to: CGPoint(x: p.x + 6, y: p.y - 6)); x.addLine(to: CGPoint(x: p.x - 6, y: p.y + 6))
            ctx.stroke(x, with: .color(Lab.danger), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ctx.draw(Text(f.title).font(Lab.mono(10).weight(.semibold)).foregroundStyle(Lab.danger), at: CGPoint(x: p.x + 10, y: p.y + 12), anchor: .leading)
        }

        // the real rocket so far (live launch)
        if let live, live.samples.count > 1 {
            var path = Path(); path.move(to: P(live.samples[0].position))
            for s in live.samples.dropFirst() { path.addLine(to: P(s.position)) }
            ctx.stroke(path, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            if let last = live.samples.last {
                let p = P(last.position)
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(.white), lineWidth: 1.5)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(.white))
                ctx.draw(Text("LIVE").font(Brand.label(9)).foregroundStyle(.white), at: CGPoint(x: p.x + 13, y: p.y), anchor: .leading)
            }
        }

        // the rocket at the cursor: position and attitude straight from the sample
        if let i = samples.index(atTime: cursor) {
            let s = samples[i], p = P(s.position)
            let nose = Vec3(cos(s.pitch) * sin(s.yaw), cos(s.pitch) * cos(s.yaw), sin(s.pitch))
            let du = proj.mode == .side ? nose.x * proj.dir.x + nose.y * proj.dir.y : nose.y
            let dv = proj.mode == .side ? nose.z : nose.x
            let ang = atan2(-dv * sc.y, du * sc.x)
            var g = ctx
            g.translateBy(x: p.x, y: p.y); g.rotate(by: .radians(ang))
            g.fill(Path(ellipseIn: CGRect(x: -16, y: -16, width: 32, height: 32)), with: .radialGradient(Gradient(colors: [Brand.telemetry.opacity(0.55), .clear]), center: .zero, startRadius: 0, endRadius: 16))
            var body = Path(); body.move(to: CGPoint(x: 11, y: 0)); body.addLine(to: CGPoint(x: -7, y: 4.5)); body.addLine(to: CGPoint(x: -4, y: 0)); body.addLine(to: CGPoint(x: -7, y: -4.5)); body.closeSubpath()
            g.fill(body, with: .color(.white))
            let tag = String(format: "t %.1f s  %d m  %d m/s", s.t, Int(s.position.z), Int(s.speed))
            let right = p.x < size.width - 150
            ctx.draw(Text(tag).font(Lab.mono(10).weight(.semibold)).foregroundStyle(Lab.ink), at: CGPoint(x: p.x + (right ? 16 : -16), y: max(12, p.y - 18)), anchor: right ? .leading : .trailing)
        }
    }

    private func drawCourse(_ ctx: inout GraphicsContext, _ proj: PathProjection, _ size: CGSize, _ sc: (x: Double, y: Double)) {
        func P(_ v: Vec3) -> CGPoint { proj.point(v, in: size) }
        let d = Vec3(proj.dir.x, proj.dir.y, 0)
        switch course.corridor {
        case let .tube(a, b, r):
            if proj.mode == .side {
                var q = Path(); q.move(to: P(a - d * r)); q.addLine(to: P(b - d * r)); q.addLine(to: P(b + d * r)); q.addLine(to: P(a + d * r)); q.closeSubpath()
                ctx.fill(q, with: .color(Brand.telemetry.opacity(0.06)))
                ctx.stroke(q, with: .color(Brand.telemetry.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
        case let .box(a, b, w, _, _, _):
            if proj.mode == .top {
                var q = Path(); q.move(to: P(Vec3(a.x - w, a.y, 0))); q.addLine(to: P(Vec3(b.x - w, b.y, 0))); q.addLine(to: P(Vec3(b.x + w, b.y, 0))); q.addLine(to: P(Vec3(a.x + w, a.y, 0))); q.closeSubpath()
                ctx.fill(q, with: .color(Brand.telemetry.opacity(0.05)))
                ctx.stroke(q, with: .color(Brand.telemetry.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
        case let .path(points, w, _, _, _):
            if proj.mode == .top, points.count > 1 {
                var q = Path(); q.move(to: P(points[0]))
                for pt in points.dropFirst() { q.addLine(to: P(pt)) }
                ctx.stroke(q, with: .color(Brand.telemetry.opacity(0.12)), style: StrokeStyle(lineWidth: max(1, 2 * w * sc.x), lineCap: .round, lineJoin: .round))
                ctx.stroke(q, with: .color(Brand.telemetry.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
        }
        if let z = course.landingZone {
            if proj.mode == .side {
                var l = Path(); l.move(to: P(z.centre - d * z.radius)); l.addLine(to: P(z.centre + d * z.radius))
                ctx.stroke(l, with: .color(Brand.ignition.opacity(0.9)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                ctx.draw(Text("LANDING ZONE").font(Brand.label(8.5)).foregroundStyle(Brand.ignition), at: CGPoint(x: P(z.centre).x, y: P(z.centre).y + 10), anchor: .top)
            } else {
                let c = P(z.centre), rx = z.radius * sc.x
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - rx, width: 2 * rx, height: 2 * rx)), with: .color(Brand.ignition.opacity(0.8)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
        }
        for (i, g) in course.gates.enumerated() where proj.mode == .top {
            var l = Path(); l.move(to: P(g.centre - Vec3(g.innerRadius, 0, 0))); l.addLine(to: P(g.centre + Vec3(g.innerRadius, 0, 0)))
            ctx.stroke(l, with: .color(Brand.trajectory), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            ctx.draw(Text("G\(i + 1)").font(Brand.label(9)).foregroundStyle(Brand.trajectory), at: CGPoint(x: P(g.centre).x + 10, y: P(g.centre).y), anchor: .leading)
        }
        let gp = P(course.goal)
        ctx.stroke(Path(ellipseIn: CGRect(x: gp.x - 7, y: gp.y - 7, width: 14, height: 14)), with: .color(Brand.ignition), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
        let eventBesideGoal = events.contains { event in
            guard let i = samples.index(atTime: event.time) else { return false }
            let ep = P(samples[i].position)
            return abs(ep.x - gp.x) < 80 && abs(ep.y - gp.y) < 18
        }
        let labelOnLeft = eventBesideGoal && gp.x > 55
        ctx.draw(Text("GOAL").font(Brand.label(8.5)).foregroundStyle(Brand.ignition),
                 at: CGPoint(x: gp.x + (labelOnLeft ? -10 : 10), y: gp.y),
                 anchor: labelOnLeft ? .trailing : .leading)
    }

    // MARK: time strip

    private var strip: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let T = max(duration, 0.1), zmax = max(samples.map { $0.position.z }.max() ?? 1, 1)
                func pt(_ t: Double, _ z: Double) -> CGPoint { CGPoint(x: t / T * size.width, y: size.height - 4 - CGFloat(max(0, z) / zmax) * (size.height - 10)) }
                var area = Path(); area.move(to: CGPoint(x: 0, y: size.height))
                let stride = max(1, samples.count / 300)
                for i in Swift.stride(from: 0, to: samples.count, by: stride) { area.addLine(to: pt(samples[i].t, samples[i].position.z)) }
                area.addLine(to: CGPoint(x: size.width, y: size.height)); area.closeSubpath()
                ctx.fill(area, with: .linearGradient(Gradient(colors: [Brand.telemetry.opacity(0.35), Brand.telemetry.opacity(0.02)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                var line = Path(); var first = true
                for i in Swift.stride(from: 0, to: samples.count, by: stride) { let p = pt(samples[i].t, samples[i].position.z); if first { line.move(to: p); first = false } else { line.addLine(to: p) } }
                ctx.stroke(line, with: .color(Brand.telemetry), lineWidth: 1.6)
                for e in events { let x = e.time / T * size.width; var t = Path(); t.move(to: CGPoint(x: x, y: size.height - 7)); t.addLine(to: CGPoint(x: x, y: size.height)); ctx.stroke(t, with: .color(Brand.ignition), lineWidth: 2) }
                if let l = live?.samples.last { let x = l.t / T * size.width; var t = Path(); t.move(to: CGPoint(x: x, y: 0)); t.addLine(to: CGPoint(x: x, y: size.height)); ctx.stroke(t, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [2, 3])) }
                let cx = min(max(cursor, 0), T) / T * size.width
                var c = Path(); c.move(to: CGPoint(x: cx, y: 0)); c.addLine(to: CGPoint(x: cx, y: size.height))
                ctx.stroke(c, with: .color(.white), lineWidth: 1.5)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 4, y: 0, width: 8, height: 8)), with: .color(.white))
                ctx.draw(Text("altitude over time").font(Lab.mono(9)).foregroundStyle(Lab.faint), at: CGPoint(x: size.width - 4, y: 2), anchor: .topTrailing)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in cursor = min(max(g.location.x / geo.size.width, 0), 1) * duration }
                .onEnded { _ in onScrubEnd() })
        }
        .background(Color(red: 0.02, green: 0.03, blue: 0.1).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
