import SwiftUI
import UIKit
import RealityKit
import SpacecraftCore
import FlightSim
import FlightRunner
import Curriculum
import LabUI

/// The "in space" scene. The launch range shows the flight at life size; this scene lifts the whole path into a
/// room-sized diorama above a curved planet so the player can see where the code sent the craft and whether it worked.
///
/// Three modes share one diorama:
/// - forecast: nothing flown yet, the violet forecast of the current code
/// - live: the flight is running, the path grows behind the craft
/// - review: the flight is over, the finished path with pins, a replay and the verdict
struct SpaceImmersiveView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @Environment(\.openWindow) private var openWindow
    @State private var scene = SpaceScene()

    var switcher: SpaceSwitcher { SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace) }

    var body: some View {
        RealityView { content, _ in
            content.add(scene.root)
            scene.buildSky()
            scene.buildPlanet()
            await scene.buildCraft(model.craft)
            scene.show(forecast: model.preview, course: model.mission.course)
            scene.subscription = content.subscribe(to: SceneEvents.Update.self) { [model, scene] e in
                model.flight.tick(e.deltaTime)
                scene.frame(dt: e.deltaTime, flight: model.flight)
            }
        } update: { content, attachments in
            scene.place(attachments)
        } attachments: {
            Attachment(id: "verdict") {
                VerdictCard(scene: scene, verdict: verdict, onReplay: { scene.startReplay() },
                            onLaunch: { Task { await switcher.show(.range) } },
                            onCode: { openWindow(id: WindowID.code) },
                            onAnalysis: { openWindow(id: WindowID.analysis) })
                    .environment(model)
            }
            ForEach(scene.pins) { pin in Attachment(id: "pin-\(pin.id)") { PinLabel(pin: pin) } }
            ForEach(scene.ladder, id: \.self) { alt in Attachment(id: "alt-\(alt)") { AltitudeLabel(metres: alt) } }
        }
        .task(id: reviewKey) {
            scene.show(forecast: model.preview, course: model.mission.course)
            if model.flight.phase == .finished, let r = model.lastReport { scene.review(r, course: model.mission.course, launch: model.flight.launchID) }
        }
        .task(id: model.craft) { await scene.buildCraft(model.craft) }
        .onChange(of: model.flight.launchID) { scene.beginLive(launch: model.flight.launchID, forecast: model.preview) }
        .onAppear { if model.flight.phase == .flying { scene.beginLive(launch: model.flight.launchID, forecast: model.preview) } }
    }

    struct ReviewKey: Hashable { var launch: Int; var phase: FlightController.Phase; var previewSamples: Int; var previewApogee: Double; var reportApogee: Double?; var mission: String }
    var reviewKey: ReviewKey {
        ReviewKey(launch: model.flight.launchID, phase: model.flight.phase, previewSamples: model.preview?.samples.count ?? 0,
                  previewApogee: model.preview?.result.apogee ?? 0, reportApogee: model.lastReport?.result.apogee, mission: model.mission.id)
    }

    var verdict: FlightVerdict {
        let live = model.flight.phase == .flying || model.flight.phase == .paused
        return FlightVerdict.make(live: live, result: live ? nil : model.lastReport?.result, faults: model.lastReport?.faults ?? [],
                                  forecast: model.preview, gateCount: model.mission.course.gates.count)
    }
}

// MARK: - Scene

@MainActor @Observable
final class SpaceScene {
    enum Mode { case forecast, live, review }

    @ObservationIgnored let root = Entity()
    @ObservationIgnored let diorama = Entity()        // everything scaled to the path
    @ObservationIgnored private let forecastHolder = Entity()
    @ObservationIgnored private let pathHolder = Entity()
    @ObservationIgnored private let gateHolder = Entity()
    @ObservationIgnored private let ladderHolder = Entity()
    @ObservationIgnored private let labelHolder = Entity()
    @ObservationIgnored private let marker = Entity()
    @ObservationIgnored private var craftModel: Entity?
    @ObservationIgnored private var segments: [(entity: ModelEntity, t: Double)] = []
    @ObservationIgnored private var materials: [Int: UnlitMaterial] = [:]
    @ObservationIgnored var subscription: EventSubscription?
    @ObservationIgnored private var attached: Set<String> = []

    private(set) var mode: Mode = .forecast
    private(set) var pins: [TrajectoryPin] = []
    private(set) var ladder: [Int] = []
    private(set) var replaying = false
    var replayT = 0.0
    var replaySpeed = 1.0
    private(set) var duration = 0.0

    @ObservationIgnored private var layout: TrajectoryLayout = .empty
    @ObservationIgnored private var forecastLayout: TrajectoryLayout = .empty
    @ObservationIgnored private var scale: Float = 0.002
    @ObservationIgnored private var origin = Vec3.zero
    @ObservationIgnored private var markerScale: Float = 1
    @ObservationIgnored private var autoReplayed = -1
    @ObservationIgnored private var liveLaunch = -1
    @ObservationIgnored private var liveConsumed = 0
    @ObservationIgnored private var liveLastT = -1.0
    @ObservationIgnored private var liveLastPos: SIMD3<Float>?
    @ObservationIgnored private var liveMaxSpeed = 1.0
    private static let height: Float = 2.2          // metres the path fills in the room
    private static let planetRadius: Float = 3.4    // diorama metres

    init() {
        root.position = [0, 0.25, -2.3]
        root.addChild(diorama)
        for h in [forecastHolder, pathHolder, gateHolder, ladderHolder, labelHolder, marker] { diorama.addChild(h) }
        marker.isEnabled = false
    }

    /// Course frame to diorama metres.
    private func d(_ v: Vec3) -> SIMD3<Float> { rk(v - origin) * scale }

    // MARK: Static dressing

    func buildSky() {
        var rng = SeededRNG(seed: 11)
        let mats = [UnlitMaterial(color: .white), UnlitMaterial(color: UIColor(red: 0.7, green: 0.82, blue: 1, alpha: 1)), UnlitMaterial(color: UIColor(red: 1, green: 0.88, blue: 0.75, alpha: 1))]
        let mesh = MeshResource.generateSphere(radius: 0.05)
        let sky = Entity()
        for _ in 0..<420 {
            let az = Float(rng.next()) * 2 * .pi, el = Float(rng.next()) * 1.3 - 0.15, r = Float(32 + rng.next() * 12)
            let s = ModelEntity(mesh: mesh, materials: [mats[Int(rng.next() * 3) % 3]])
            s.position = [r * cos(el) * sin(az), r * sin(el), -r * cos(el) * cos(az)]
            s.scale = SIMD3(repeating: Float(0.4 + rng.next() * 1.6))
            sky.addChild(s)
        }
        root.addChild(sky)
    }

    func buildPlanet() {
        let r = Self.planetRadius
        var m = UnlitMaterial(color: UIColor(red: 0.04, green: 0.06, blue: 0.14, alpha: 1))
        if let tex = Self.planetTexture() { m.color = .init(tint: .white, texture: .init(tex)) }
        let planet = ModelEntity(mesh: .generateSphere(radius: r), materials: [m])
        planet.position = [0, -r, 0]
        diorama.addChild(planet)
        let glow = ModelEntity(mesh: .generateSphere(radius: r * 1.014), materials: [PartMeshFactory.unlit(0x4FDBF2, alpha: 0.2)])
        glow.position = [0, -r, 0]
        diorama.addChild(glow)
        let pad = ModelEntity(mesh: .generateCylinder(height: 0.004, radius: 0.1), materials: [PartMeshFactory.unlit(0xFF6B21, alpha: 0.85)])
        pad.position = [0, 0.002, 0]
        diorama.addChild(pad)
    }

    /// Dark globe with a latitude and longitude grid and sparse lights, drawn once.
    private static func planetTexture() -> TextureResource? {
        let size = CGSize(width: 1024, height: 512)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [UIColor(red: 0.10, green: 0.18, blue: 0.42, alpha: 1).cgColor, UIColor(red: 0.04, green: 0.08, blue: 0.22, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            c.setStrokeColor(UIColor(red: 0.31, green: 0.86, blue: 0.95, alpha: 0.55).cgColor)
            c.setLineWidth(2)
            for i in 0...24 { let x = size.width * CGFloat(i) / 24; c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x, y: size.height)) }
            for i in 0...12 { let y = size.height * CGFloat(i) / 12; c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: size.width, y: y)) }
            c.strokePath()
            var rng = SeededRNG(seed: 3)
            for _ in 0..<900 {
                let x = CGFloat(rng.next()) * size.width, y = CGFloat(rng.next()) * size.height, a = 0.1 + rng.next() * 0.5
                c.setFillColor(UIColor(red: 1, green: 0.75, blue: 0.4, alpha: a).cgColor)
                c.fillEllipse(in: CGRect(x: x, y: y, width: 2.2, height: 2.2))
            }
        }
        guard let cg = img.cgImage else { return nil }
        return try? TextureResource(image: cg, options: .init(semantic: .color))
    }

    func buildCraft(_ craft: CraftDesign) async {
        craftModel?.removeFromParent()
        let e = await CraftBuilder.build(craft)
        let length = Float(max(craft.stackSpans.last?.top ?? 6, 2))
        markerScale = 0.11 / length
        e.scale = SIMD3(repeating: markerScale)
        e.position = [0, -0.055, 0]               // centre the craft on the marker point
        craftModel = e
        marker.children.removeAll()
        marker.addChild(e)
        let halo = ModelEntity(mesh: .generateSphere(radius: 0.085), materials: [PartMeshFactory.unlit(0xFF6B21, alpha: 0.16)])
        marker.addChild(halo)
    }

    // MARK: Showing paths

    private func fit(_ l: TrajectoryLayout) {
        guard !l.points.isEmpty else { return }
        let extent = Float(max(l.extent, 300))
        scale = Self.height / extent
        origin = Vec3(l.centre.x, l.centre.y, 0)
    }

    func show(forecast: FlightReport?, course: Course) {
        forecastHolder.children.removeAll()
        if let f = forecast, f.compileError == nil, !f.samples.isEmpty {
            forecastLayout = TrajectoryLayout.make(samples: f.samples, events: [], result: f.result, gates: course.gates, maxPoints: 120)
        } else {
            forecastLayout = .empty
        }
        if mode != .review { fit(forecastLayout.points.isEmpty ? layout : forecastLayout) }
        else if !layout.points.isEmpty { fit(layout) }
        for (i, p) in forecastLayout.points.enumerated() where i % 2 == 0 {
            let b = ModelEntity(mesh: .generateSphere(radius: 0.011), materials: [PartMeshFactory.unlit(0xB78FFF, alpha: 0.7)])
            b.position = d(p.position)
            forecastHolder.addChild(b)
        }
        buildGates(course)
        buildLadder(top: max(forecastLayout.points.map { $0.position.z }.max() ?? 0, layout.points.map { $0.position.z }.max() ?? 0))
    }

    func beginLive(launch: Int, forecast: FlightReport?) {
        mode = .live; replaying = false
        pathHolder.children.removeAll(); segments.removeAll(); pins = []; layout = .empty
        liveLaunch = launch; liveConsumed = 0; liveLastT = -1; liveLastPos = nil; liveMaxSpeed = max(forecastLayout.maxSpeed, 1)
        marker.isEnabled = true
    }

    func review(_ report: FlightReport, course: Course, launch: Int) {
        guard !report.samples.isEmpty else { return }
        mode = .review
        layout = TrajectoryLayout.make(samples: report.samples, events: TrajectoryLayout.parseEvents(report.events), result: report.result, gates: course.gates)
        fit(forecastLayout.points.isEmpty ? layout : merged(forecastLayout, layout))
        duration = layout.duration
        pathHolder.children.removeAll(); segments.removeAll()
        buildSegments(layout.points, maxSpeed: layout.maxSpeed)
        pins = layout.pins.filter { if case .gate = $0.kind { return false }; return true }
        rebuildForecastAfterFit(course)
        buildGates(course); buildLadder(top: layout.points.map { $0.position.z }.max() ?? 0)
        marker.isEnabled = true
        if autoReplayed != launch { autoReplayed = launch; startReplay() } else { setReplay(duration) }
    }

    private func merged(_ a: TrajectoryLayout, _ b: TrajectoryLayout) -> TrajectoryLayout {
        var m = b; m.minBound = simd_min(a.minBound, b.minBound); m.maxBound = simd_max(a.maxBound, b.maxBound); return m
    }

    private func rebuildForecastAfterFit(_ course: Course) {
        forecastHolder.children.removeAll()
        for (i, p) in forecastLayout.points.enumerated() where i % 2 == 0 {
            let b = ModelEntity(mesh: .generateSphere(radius: 0.011), materials: [PartMeshFactory.unlit(0xB78FFF, alpha: 0.7)])
            b.position = d(p.position)
            forecastHolder.addChild(b)
        }
    }

    // MARK: Geometry

    private func material(for speed: Double, max: Double) -> UnlitMaterial {
        let bucket = Int(Swift.min(9, speed / Swift.max(max, 1) * 10))
        if let m = materials[bucket] { return m }
        let t = CGFloat(bucket) / 9
        let m = UnlitMaterial(color: UIColor(red: 0.31 + 0.69 * t, green: 0.86 - 0.44 * t, blue: 0.95 - 0.82 * t, alpha: 1))
        materials[bucket] = m
        return m
    }

    private func segment(from a: SIMD3<Float>, to b: SIMD3<Float>, speed: Double, maxSpeed: Double) -> ModelEntity? {
        let v = b - a, len = simd_length(v)
        guard len > 1e-5 else { return nil }
        let e = ModelEntity(mesh: .generateCylinder(height: len, radius: 0.0085), materials: [material(for: speed, max: maxSpeed)])
        e.position = (a + b) / 2
        e.orientation = simd_quatf(from: [0, 1, 0], to: v / len)
        return e
    }

    private func buildSegments(_ pts: [TrajectoryPoint], maxSpeed: Double) {
        for i in 1..<max(pts.count, 1) {
            guard let e = segment(from: d(pts[i - 1].position), to: d(pts[i].position), speed: pts[i].speed, maxSpeed: maxSpeed) else { continue }
            pathHolder.addChild(e); segments.append((e, pts[i].t))
        }
    }

    private func buildGates(_ course: Course) {
        gateHolder.children.removeAll()
        for (i, g) in course.gates.enumerated() {
            let passed: Bool = { if case let .gate(p)? = layout.pins.first(where: { if case .gate = $0.kind { return $0.label == g.id }; return false })?.kind { return p }; return false }()
            let colour: UInt32 = mode == .review ? (passed ? 0x4FDBF2 : 0xFF6B21) : 0xB78FFF
            let r = max(Float(g.innerRadius) * scale * 4, 0.045), c = d(g.centre)
            for k in 0..<28 {
                let a = Float(k) / 28 * 2 * .pi
                let b = ModelEntity(mesh: .generateSphere(radius: 0.007), materials: [PartMeshFactory.unlit(colour)])
                b.position = c + [cos(a) * r, sin(a) * r, 0]
                gateHolder.addChild(b)
            }
            _ = i
        }
    }

    private func buildLadder(top: Double) {
        ladderHolder.children.removeAll()
        guard top > 40 else { ladder = []; return }
        let steps: [Double] = [25, 50, 100, 200, 250, 500, 1000, 2000]
        let step = steps.first { top / $0 <= 6 } ?? 2000
        var rungs: [Int] = []
        var alt = step
        while alt <= top * 1.05 { rungs.append(Int(alt)); alt += step }
        for a in rungs {
            let disc = ModelEntity(mesh: .generateCylinder(height: 0.002, radius: 0.5), materials: [PartMeshFactory.unlit(0x4FDBF2, alpha: 0.05)])
            disc.position = [0, Float(a) * scale, 0]
            ladderHolder.addChild(disc)
        }
        let mast = ModelEntity(mesh: .generateCylinder(height: Float(top) * scale * 1.05, radius: 0.002), materials: [PartMeshFactory.unlit(0x4FDBF2, alpha: 0.35)])
        mast.position = [0, Float(top) * scale * 0.525, 0]
        ladderHolder.addChild(mast)
        ladder = rungs
    }

    // MARK: Attachments

    func place(_ attachments: RealityViewAttachments) {
        if let v = attachments.entity(for: "verdict"), v.parent == nil {
            v.position = [-1.2, 1.35, 0.45]
            v.scale = SIMD3(repeating: 1.7)
            v.orientation = simd_quatf(angle: 0.5, axis: [0, 1, 0])
            root.addChild(v)
        }
        for pin in pins {
            guard let e = attachments.entity(for: "pin-\(pin.id)") else { continue }
            if e.parent == nil { e.components.set(BillboardComponent()); e.scale = SIMD3(repeating: 2.4); labelHolder.addChild(e) }
            e.position = d(pin.position) + [0.05, 0.14, 0]
        }
        for alt in ladder {
            guard let e = attachments.entity(for: "alt-\(alt)") else { continue }
            if e.parent == nil { e.components.set(BillboardComponent()); e.scale = SIMD3(repeating: 2.0); labelHolder.addChild(e) }
            e.position = [0.56, Float(alt) * scale + 0.04, 0]
        }
    }

    // MARK: Replay and live

    func startReplay() {
        guard mode == .review, duration > 0 else { return }
        replayT = 0; replaying = true
        for s in segments { s.entity.isEnabled = false }
    }

    private func setReplay(_ t: Double) {
        replayT = t; replaying = false
        for s in segments { s.entity.isEnabled = s.t <= t + 1e-6 }
        pose(at: t)
    }

    func scrub(_ t: Double) { replaying = false; setReplay(min(max(t, 0), duration)) }

    private func pose(at t: Double) {
        let p = layout.position(at: t), q = layout.position(at: min(t + 0.4, duration))
        marker.position = d(p)
        let dir = d(q) - d(p)
        if simd_length(dir) > 1e-5 { marker.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(dir)) }
    }

    func frame(dt: Double, flight: FlightController) {
        switch mode {
        case .review where replaying:
            replayT += dt * replaySpeed * max(duration / 10, 1)
            if replayT >= duration { setReplay(duration) } else {
                for s in segments { s.entity.isEnabled = s.t <= replayT }
                pose(at: replayT)
            }
        case .live:
            guard let sim = flight.sim, flight.launchID == liveLaunch else { return }
            let samples = sim.samples
            let every = max(0.25, forecastLayout.duration / 280)
            while liveConsumed < samples.count {
                let s = samples[liveConsumed]; liveConsumed += 1
                guard s.t - liveLastT >= every else { continue }
                liveLastT = s.t; liveMaxSpeed = max(liveMaxSpeed, s.speed)
                let p = d(s.position)
                if let prev = liveLastPos, let e = segment(from: prev, to: p, speed: s.speed, maxSpeed: liveMaxSpeed) { pathHolder.addChild(e); segments.append((e, s.t)) }
                liveLastPos = p
            }
            marker.position = d(flight.position)
            let v = sim.velocity
            if simd_length(v) > 0.5 { marker.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(rk(v))) }
        default: break
        }
    }
}

// MARK: - Labels and card

private struct PinLabel: View {
    let pin: TrajectoryPin
    var tint: Color {
        switch pin.kind {
        case .failure: Lab.danger
        case .apogee: Brand.ignition
        case .landing: Brand.telemetry
        default: Brand.trajectory
        }
    }
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 9, height: 9)
            Text(pin.label.uppercased()).font(Brand.label(11)).tracking(1.4).foregroundStyle(Brand.ink)
            if pin.kind == .event || pin.kind == .failure { Text(String(format: "%.1fs", pin.t)).font(Brand.label(10)).foregroundStyle(Brand.dim) }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Brand.space.opacity(0.9), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.7), lineWidth: 1))
    }
}

private struct AltitudeLabel: View {
    let metres: Int
    var body: some View {
        Text("\(metres) m").font(Brand.label(10)).foregroundStyle(Brand.telemetry.opacity(0.85))
            .padding(.horizontal, 8).padding(.vertical, 2).background(Brand.space.opacity(0.7), in: Capsule())
    }
}

/// Did the code work? Verdict, the facts behind it, forecast comparison, live readouts and replay controls.
private struct VerdictCard: View {
    @Environment(AppModel.self) private var model
    @Bindable var scene: SpaceScene
    let verdict: FlightVerdict
    var onReplay: () -> Void
    var onLaunch: () -> Void
    var onCode: () -> Void
    var onAnalysis: () -> Void

    var tint: Color {
        switch verdict.state {
        case .worked: Brand.telemetry
        case .failed: Lab.danger
        case .flying: Brand.ignition
        case .noFlight: Brand.trajectory
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Rectangle().fill(tint).frame(width: 26, height: 4).clipShape(Capsule())
                Text("SPACE VIEW").font(Brand.label(11)).tracking(3).foregroundStyle(Brand.dim)
            }
            Text(verdict.headline).font(Brand.display(30)).foregroundStyle(tint).tracking(1)
            Text(verdict.detail).font(.system(size: 16, weight: .medium)).foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
            if verdict.state == .flying { live }
            if !verdict.facts.isEmpty { facts }
            if let n = verdict.forecastNote { Text(n).font(Brand.label(12)).foregroundStyle(Brand.trajectory).fixedSize(horizontal: false, vertical: true) }
            if let line = verdict.line {
                Button { onCode() } label: { Label("Open code. Look at line \(line)", systemImage: "chevron.left.forwardslash.chevron.right") }
                    .buttonStyle(.bordered).tint(tint)
            }
            if scene.mode == .review { replayControls }
            legend
            HStack(spacing: 10) {
                Button("Launch scene", systemImage: "arrow.down.to.line") { onLaunch() }
                Button("Edit code", systemImage: "chevron.left.forwardslash.chevron.right") { onCode() }
                Button("Analysis", systemImage: "chart.xyaxis.line") { onAnalysis() }
            }
            .buttonStyle(.bordered).font(.system(size: 14, weight: .semibold))
        }
        .padding(28)
        .frame(width: 470, alignment: .leading)
        .labPanel(tint: tint)
    }

    var live: some View {
        let f = model.flight
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 18) {
                readout("T+", String(format: "%.1f s", f.time)); readout("ALT", "\(Int(f.altitude)) m"); readout("SPEED", "\(Int(f.speed)) m/s")
            }
            HStack {
                Picker("Speed", selection: Binding(get: { f.timeScale }, set: { f.timeScale = $0 })) {
                    Text("1x").tag(1.0); Text("4x").tag(4.0); Text("8x").tag(8.0)
                }.pickerStyle(.segmented).frame(width: 190)
                Button("Pause", systemImage: f.phase == .paused ? "play.fill" : "pause.fill") { f.togglePause() }
                Button("Abort", systemImage: "xmark") { f.abort() }.tint(Lab.danger)
            }
            .buttonStyle(.bordered)
        }
    }

    func readout(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(Brand.label(10)).tracking(2).foregroundStyle(Brand.dim)
            Text(v).font(Brand.label(18)).foregroundStyle(Brand.ink).monospacedDigit()
        }
    }

    var facts: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(verdict.facts, id: \.label) { f in
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.label).font(Brand.label(10)).tracking(2).foregroundStyle(Brand.dim)
                    Text(f.value).font(Brand.label(18)).foregroundStyle(Brand.ink)
                }
                .padding(.horizontal, 12).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.space.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    var replayControls: some View {
        HStack(spacing: 12) {
            Button(scene.replaying ? "Replaying" : "Replay", systemImage: "arrow.counterclockwise") { onReplay() }.buttonStyle(.borderedProminent).tint(Brand.ignition)
            Slider(value: Binding(get: { scene.replayT }, set: { scene.scrub($0) }), in: 0...max(scene.duration, 1))
        }
    }

    var legend: some View {
        HStack(spacing: 14) {
            key(Brand.telemetry, "slow"); key(Brand.ignition, "fast"); key(Brand.trajectory, "forecast")
        }
        .font(Brand.label(11)).foregroundStyle(Brand.dim)
    }
    func key(_ c: Color, _ t: String) -> some View { HStack(spacing: 5) { Circle().fill(c).frame(width: 8, height: 8); Text(t.uppercased()).tracking(1.5) } }
}

// MARK: - Hand-off from the launch range

/// Follows the flight into the space scene: once the craft has climbed, and again when the flight ends,
/// so the player ends up looking at the path and the verdict. Once per launch, so "Launch scene" does not bounce back.
struct FollowToSpace: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace

    var shouldFollow: Bool {
        let f = model.flight
        guard model.followToSpace, !model.learnActive, model.openSpace == .range, model.followedLaunch != f.launchID, f.phase != .idle else { return false }
        let climb = max(120, 0.45 * (model.preview?.result.apogee ?? 500))
        return f.phase == .finished || f.altitude >= climb
    }

    func body(content: Content) -> some View {
        content.onChange(of: shouldFollow) { _, go in
            guard go else { return }
            model.followedLaunch = model.flight.launchID
            Task { await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.space) }
        }
    }
}

/// Beside the launch HUD: jump to the space view by hand, and say whether the flight follows automatically.
struct SpaceViewButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 10) {
            Button { Task { await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.space) } } label: {
                Label("SPACE VIEW", systemImage: "sparkles").font(Brand.label(13)).tracking(2)
            }
            .buttonStyle(.borderedProminent).tint(Brand.ignition)
            Toggle("Follow flight", isOn: $model.followToSpace).font(Brand.label(11)).tracking(1.5).toggleStyle(.switch)
        }
        .padding(16)
        .labPanel(corner: 24, tint: Brand.ignition)
        .frame(width: 230)
    }
}
