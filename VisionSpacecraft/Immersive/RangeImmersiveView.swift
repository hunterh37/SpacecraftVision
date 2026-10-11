import SwiftUI
import UIKit
import RealityKit
import RealKit
import RealLibrary
import SpacecraftCore
import FlightSim
import FlightRunner
import Curriculum

/// Course frame (x east, y north, z up) to RealityKit (x right, y up, -z ahead).
@inline(__always) func rk(_ v: Vec3) -> SIMD3<Float> { SIMD3(Float(v.x), Float(v.z), Float(-v.y)) }

/// Launch range (specs/03): desert pad 60 m ahead of the viewing platform, course props, live craft,
/// preview ribbon, ground / chase / tabletop views and the telemetry HUD.
struct RangeImmersiveView: View {
    @Environment(AppModel.self) private var model
    @State private var scene = RangeScene()

    var body: some View {
        RealityView { content, attachments in
            // Every mission is flown in space: star sphere, planet, sun light, no atmosphere haze.
            if let env = SpaceBackdrop.environment() {
                content.add(env.root)
                scene.env = env
            }
            content.add(SpaceBackdrop.sky())
            content.add(scene.skyHolder)
            content.add(scene.lightHolder)
            scene.updateSky(style: model.skyStyle, timeOfDay: model.mission.course.timeOfDay)
            content.add(scene.root)
            if let hud = attachments.entity(for: "hud") {
                scene.hud = hud
                content.add(hud)
                if let callout = attachments.entity(for: "callout") {
                    // Left of the HUD, angled toward the viewer; follows the HUD in every view.
                    callout.position = [-0.6, 0.04, 0.03]
                    callout.orientation = simd_quatf(angle: 0.3, axis: [0, 1, 0])
                    hud.addChild(callout)
                    scene.callout = callout
                }
                if let btn = attachments.entity(for: "spaceBtn") {
                    btn.position = [0.62, 0.04, 0.03]
                    btn.orientation = simd_quatf(angle: -0.3, axis: [0, 1, 0])
                    hud.addChild(btn)
                }
            }
            if let deck = attachments.entity(for: "lesson") {
                // Left of the viewer, angled in, beside the pad sightline.
                deck.position = [-0.95, 1.2, -1.05]
                deck.orientation = simd_quatf(angle: 0.55, axis: [0, 1, 0])
                deck.isEnabled = model.learnActive
                content.add(deck)
                scene.deck = deck
            }
            content.add(scene.indicators.world)
            await scene.buildStatic(course: model.mission.course)
            await scene.rebuildCraft(model.craft)
            scene.applyView(model.flightView, course: model.mission.course)
            scene.subscription = content.subscribe(to: SceneEvents.Update.self) { [model, scene] e in
                model.flight.tick(e.deltaTime)
                scene.updateCraft(model.flight, view: model.flightView, course: model.mission.course, dt: e.deltaTime)
                model.walkthrough.tick(e.deltaTime, model: model)
                scene.updateIndicators(model, dt: Float(e.deltaTime))
                SpaceBackdrop.tumble(scene.asteroidHolder, dt: Float(e.deltaTime))
            }
        } update: { _, _ in
        } attachments: {
            Attachment(id: "hud") {
                FlightHUDView()
                    .environment(model)
            }
            Attachment(id: "spaceBtn") {
                SpaceViewButton()
                    .environment(model)
            }
            Attachment(id: "lesson") {
                LessonDeckView()
                    .environment(model)
            }
            Attachment(id: "callout") {
                CalloutView()
                    .environment(model)
                    .animation(.easeOut(duration: 0.35), value: model.walkthrough.current?.id)
            }
        }
        .task(id: model.craft) { await scene.rebuildCraft(model.craft) }
        .task(id: model.mission.id) { await scene.buildStatic(course: model.mission.course) }
        .task(id: SkyKey(style: model.skyStyle, timeOfDay: model.mission.course.timeOfDay)) {
            scene.updateSky(style: model.skyStyle, timeOfDay: model.mission.course.timeOfDay)
        }
        .task(id: RibbonKey(n: model.preview?.samples.count ?? 0, t: model.preview?.result.duration ?? 0,
                           sig: RibbonKey.signature(model.preview), view: model.flightView)) {
            scene.rebuildRibbon(model.preview, view: model.flightView)
            scene.applyView(model.flightView, course: model.mission.course)
        }
        .onChange(of: model.flight.launchID) { scene.resetCraftPose(); scene.resetGates() }
        .onChange(of: model.flight.gates) { _, n in scene.markGatePassed(n) }
        .onChange(of: model.walkthrough.successCount) { scene.playSuccess() }
        .onAppear { if !model.learnActive { model.walkthrough.startIfNeeded() } }
        .onChange(of: model.learnActive) { _, on in scene.deck?.isEnabled = on }
        .modifier(FollowToSpace())
    }

    struct SkyKey: Hashable { var style: SkyStyle; var timeOfDay: TimeOfDay }
    struct RibbonKey: Hashable {
        var n: Int; var t: Double; var sig: Int; var view: FlightView
        /// Sum of sampled positions so equal-length paths with different shapes still refresh.
        static func signature(_ r: FlightReport?) -> Int {
            guard let s = r?.samples, !s.isEmpty else { return 0 }
            var h = Hasher()
            for i in Swift.stride(from: 0, to: s.count, by: max(1, s.count / 32)) {
                h.combine(Int(s[i].position.x * 10)); h.combine(Int(s[i].position.y * 10)); h.combine(Int(s[i].position.z * 10))
            }
            return h.finalize()
        }
    }
}

@MainActor
final class RangeScene {
    let root = Entity()           // world root, moved/scaled per view
    let skyHolder = Entity()      // stays around the viewer when the range shifts for chase/tabletop
    let lightHolder = Entity()
    private let sun = Entity()
    private let fill = Entity()
    let staticHolder = Entity()
    let courseHolder = Entity()
    let craftHolder = Entity()    // positioned by the sim
    let ribbonHolder = Entity()
    let asteroidHolder = Entity()
    var craftModel: Entity?
    var poser: CraftPoser?
    var windsock: Entity?

    /// Head yaw to the downwind direction, sock sag from speed: calm -76 deg, breeze -28 deg, level at 10 m/s.
    func poseWindsock(_ wind: Wind) {
        guard let windsock, !PartMeshFactory.isPlaceholder(windsock) else { return }
        let v = wind.vector(altitude: 6)
        let speed = Float(simd_len(v))
        let d = rk(v)
        let yaw = speed > 0.01 ? atan2(-d.z, d.x) * 180 / .pi : 0
        let sag: Float = speed >= 10 ? 0 : speed >= 5 ? -28 + 28 * (speed - 5) / 5 : -76 + 48 * speed / 5
        windsock.setJoints(["head": yaw, "sock": sag])
    }
    var plume: ModelEntity?
    var drogue: ModelEntity?
    var mainChute: ModelEntity?
    var marker: ModelEntity?
    var hud: Entity?
    var callout: Entity?
    var deck: Entity?
    let indicators = SpatialIndicators()
    /// Highest predicted sample, course frame, for the walkthrough's path step.
    private(set) var ribbonApex: Vec3?
    var env: RealEnvironment?
    var subscription: EventSubscription?
    private var builtStatic = false
    private var builtCourse: String?
    private var gateBeacons: [ModelEntity] = []
    private var chaseFocus: SIMD3<Float>?

    init() {
        skyHolder.position.y = -1.6
        lightHolder.addChild(sun)
        lightHolder.addChild(fill)
        root.addChild(staticHolder)
        root.addChild(courseHolder)
        root.addChild(ribbonHolder)
        root.addChild(craftHolder)
        root.addChild(asteroidHolder)
        root.addChild(indicators.course)
        SpaceBackdrop.Tumble.registerComponent()
    }

    func updateSky(style: SkyStyle, timeOfDay: TimeOfDay) {
        skyHolder.children.removeAll()
        if let sky = SkyBackdrop.make(style, timeOfDay: timeOfDay, radius: 3000) { skyHolder.addChild(sky) }
        SceneLighting.update(sun: sun, fill: fill, style: style, timeOfDay: timeOfDay)
    }

    // MARK: Walkthrough indicators

    func updateIndicators(_ model: AppModel, dt: Float) {
        indicators.tick(dt)
        let target: WalkTarget?
        let anchor: Entity?
        if let step = model.walkthrough.current { target = step.target; anchor = callout }
        else if model.learnActive, model.flight.phase != .flying { target = Self.lessonTarget(model.lessonStage); anchor = deck }
        else { indicators.hideAll(); return }
        guard let anchor else { indicators.hideAll(); return }
        let from = anchor.position(relativeTo: nil) + [0, -0.1, 0]
        let s = root.scale.x
        switch target {
        case .pad:
            indicators.show(beacon: true, haloAt: nil, leader: (from, root.convert(position: [0, 4, 0], to: nil)))
        case .ribbon:
            guard let apex = ribbonApex else { indicators.show(beacon: false, haloAt: nil, leader: nil); return }
            let p = root.convert(position: rk(apex) + [0, 0.5, 0], to: nil)
            indicators.show(beacon: false, haloAt: (p, 6 * s), leader: (from, p))
        case .craft:
            let base = root.convert(position: craftHolder.position - [0, Float(craftModel.map { -$0.position.y } ?? 2), 0] + [0, 0.1, 0],
                                    to: nil)
            indicators.show(beacon: true, haloAt: (base, 2.2 * s), leader: (from, base + [0, 3 * s, 0]))
        case .hud, nil:
            indicators.show(beacon: false, haloAt: nil, leader: nil)
        }
    }

    /// What the lesson deck points at for each stage.
    static func lessonTarget(_ stage: LessonStage) -> WalkTarget? {
        switch stage {
        case .concept, .pseudocode: .craft
        case .implement, .analyze: .ribbon
        case .run: .pad
        }
    }

    func playSuccess() {
        guard let callout else { return }
        indicators.playBurst(at: callout.position(relativeTo: nil))
    }

    func buildStatic(course: Course) async {
        if !builtStatic {
            builtStatic = true
            // Base environment: RealityHD "aerospace-range" (pad, tower, blockhouse, runway, platform, scrub).
            // Fallback: the regolith deck, planet and placeholder pad props.
            if let range = try? await RealityHD.scene("aerospace-range", seed: 1) {
                // Mount-ring top (deck 1 m - 0.05 sink + ring 1.2 m) at y = 0 where the craft stands, and the scene's
                // viewing platform at (-42, 43) turned 44.3 deg onto the app's viewer line 60 m south of the pad.
                range.position = [0, -2.15, 0]
                range.orientation = simd_quatf(angle: atan2(42, 43), axis: [0, 1, 0])
                staticHolder.addChild(range)
            } else {
                // Regolith deck and the planet below it, in place of the desert floor.
                staticHolder.addChild(SpaceBackdrop.deck())
                staticHolder.addChild(SpaceBackdrop.planet())
                staticHolder.addChild(await PartMeshFactory.entity("launch-pad").withPosition([0, -0.6, 0]))
                staticHolder.addChild(await PartMeshFactory.entity("launch-tower").withPosition([3.2, 0, 0]))
                staticHolder.addChild(await PartMeshFactory.entity("viewing-platform").withPosition([0, 0, 60]))
                // Surface rocks from RealityHD, dark and dusty.
                var rng = SplitMix64(seed: 42)
                for i in 0..<18 {
                    let a = rng.unit() * 2 * .pi, d = 40 + rng.unit() * 380
                    let p = SIMD3<Float>(Float(cos(a) * d), 0, Float(sin(a) * d))
                    if abs(p.x) < 15 && p.z > -20 && p.z < 80 { continue }
                    if let e = try? await RealityHD.entity("boulder", seed: UInt64(i + 1)) {
                        e.position = p
                        e.scale = .init(repeating: Float(1.5 + rng.unit() * 2))
                        staticHolder.addChild(e)
                    }
                }
                for (i, p) in [SIMD3<Float>(-4, 0, 57), [-4.8, 0, 56.4], [4.5, 0, 57.5]].enumerated() {
                    if let e = try? await RealityHD.entity("oil-drum", seed: UInt64(i + 1)) { e.position = p; staticHolder.addChild(e) }
                }
                if let e = try? await RealityHD.entity("cable-spool", seed: 1) { e.position = [6, 0, 4]; staticHolder.addChild(e) }
            }
            env?.illuminate(staticHolder)
        }
        guard builtCourse != course.id else { return }
        builtCourse = course.id
        // Live windsock beside the viewer, posed from the course wind (the scene's own sock is baked).
        windsock?.removeFromParent()
        let sock = await PartMeshFactory.entity("windsock")
        sock.position = rk(Vec3(14, -52, 0))
        staticHolder.addChild(sock)
        windsock = sock
        poseWindsock(course.wind)
        courseHolder.children.removeAll()
        gateBeacons.removeAll()
        // Asteroid field around the course, kept off the pad, the platform and every gate.
        asteroidHolder.children.removeAll()
        var clear: [(SIMD3<Float>, Float)] = [([0, 0, 0], 120), ([0, 0, 60], 60)]
        for g in course.gates { clear.append((rk(g.centre), Float(g.innerRadius) * 6 + 30)) }
        if let zone = course.landingZone { clear.append((rk(zone.centre), Float(zone.radius) + 60)) }
        clear.append((rk(course.goal), 80))
        // Clear tube along pad -> gates -> goal and a column above the pad, so rocks never sit on the flown line.
        let line = [Vec3.zero, Vec3(0, 0, 400)] + course.gates.map(\.centre) + [course.goal]
        for (a, b) in zip(line, line.dropFirst()) {
            let n = max(1, Int(simd_len(b - a) / 40))
            for k in 0...n { clear.append((rk(a + (b - a) * Double(k) / Double(n)), 90)) }
        }
        for z in stride(from: 0.0, through: course.extent.z, by: 60) { clear.append((rk(Vec3(0, 0, z)), 110)) }
        let ext = SIMD3<Float>(Float(course.extent.x), Float(course.extent.y), Float(course.extent.z))
        asteroidHolder.addChild(SpaceBackdrop.asteroids(extent: ext, keepClear: clear, seed: course.id.utf8.reduce(7) { $0 &* 31 &+ UInt64($1) }))
        // Landing zone pylons.
        if let zone = course.landingZone {
            for k in 0..<8 {
                let a = Double(k) / 8 * 2 * .pi
                let p = zone.centre + Vec3(cos(a) * zone.radius, sin(a) * zone.radius, 0)
                courseHolder.addChild(await PartMeshFactory.entity("pylon", seed: UInt64(k)).withPosition(rk(p)))
            }
            let disc = ModelEntity(mesh: .generateCylinder(height: 0.05, radius: Float(zone.radius)),
                                   materials: [PartMeshFactory.unlit(0x3A8A4A, alpha: 0.25)])
            disc.position = rk(zone.centre) + [0, 0.05, 0]
            courseHolder.addChild(disc)
        }
        // Ring gates: try RealityHD "ring-gate", else a torus placeholder; uniform scale r / 3.5, base hidden above 20 m.
        for g in course.gates {
            let gate = await PartMeshFactory.entity("ring-gate")
            let placeholder = PartMeshFactory.isPlaceholder(gate)
            if placeholder, g.centre.z > 20, gate.children.count > 1 { gate.children[1].isEnabled = false }
            let s = Float(g.innerRadius / 3.5)
            gate.scale = .init(repeating: s)
            // RealityHD ring-gate: 8 m ring on an A-frame, ring centre 4 m below its 9.02 m top.
            gate.position = rk(g.centre) - [0, (placeholder ? 4.5 : 5.02) * s, 0]
            courseHolder.addChild(gate)
            // Number label pole for orientation.
            let beacon = ModelEntity(mesh: .generateSphere(radius: 1.2), materials: [PartMeshFactory.unlit(0xF2C230)])
            beacon.position = rk(g.centre) + [0, Float(g.innerRadius + 3), 0]
            courseHolder.addChild(beacon)
            gateBeacons.append(beacon)
        }
        if let fy = course.finishY {
            let finish = ModelEntity(mesh: .generateBox(size: [180, 0.6, 0.6]), materials: [PartMeshFactory.unlit(0xF2F2F0, alpha: 0.6)])
            finish.position = rk(Vec3(0, fy, course.goal.z))
            courseHolder.addChild(finish)
        }
        env?.illuminate(courseHolder)
        env?.illuminate(asteroidHolder)
    }

    func rebuildCraft(_ craft: CraftDesign) async {
        let e = await CraftBuilder.build(craft)
        craftHolder.children.removeAll()
        // Rotate so the craft centre of mass sits at the holder origin.
        let com = Float(craft.stats().centerOfMass)
        e.position = [0, -com, 0]
        craftHolder.addChild(e)
        craftModel = e
        poser = CraftPoser(craft: e)
        let plume = ModelEntity(mesh: PartMeshFactory.cylinder("plume", r: 0.5, h: 6, top: 0.05), materials: [PartMeshFactory.unlit(0xFFB65C, alpha: 0.85)])
        plume.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        plume.position = [0, -com, 0]
        plume.isEnabled = false
        craftHolder.addChild(plume)
        self.plume = plume
        let canopy: (Float, UInt32) -> ModelEntity = { r, c in
            let m = ModelEntity(mesh: PartMeshFactory.lathe("canopy-\(r)", (0...10).map { i in
                let a = Float(i) / 10 * .pi / 2
                return (r * sin(a), r * 0.6 * cos(a))
            }), materials: [PartMeshFactory.paint(c)])
            m.isEnabled = false
            return m
        }
        drogue = canopy(2, 0xE8622C)
        mainChute = canopy(8, 0xF2F2F0)
        for c in [drogue!, mainChute!] { craftHolder.addChild(c) }
        let marker = ModelEntity(mesh: .generateSphere(radius: 14), materials: [PartMeshFactory.unlit(0x58C8FF)])
        marker.isEnabled = false
        craftHolder.addChild(marker)
        self.marker = marker
        env?.illuminate(craftHolder)
        resetCraftPose()
    }

    /// Gate n (1-based count) passed: beacon turns green and pulses; burst at the gate.
    func markGatePassed(_ count: Int) {
        guard count > 0, count <= gateBeacons.count else { return }
        let b = gateBeacons[count - 1]
        b.model?.materials = [PartMeshFactory.unlit(0x3FD97A)]
        var t = b.transform; t.scale = .init(repeating: 2.2)
        b.move(to: t, relativeTo: b.parent, duration: 0.25, timingFunction: .easeOut)
        indicators.playBurst(at: b.position(relativeTo: nil))
    }

    func resetGates() {
        for b in gateBeacons { b.model?.materials = [PartMeshFactory.unlit(0xF2C230)]; b.scale = .one }
    }

    func resetCraftPose() {
        chaseFocus = nil
        let com = Float(craftModel.map { -$0.position.y } ?? 2)
        craftHolder.position = [0, com, 0]
        craftHolder.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        plume?.isEnabled = false; drogue?.isEnabled = false; mainChute?.isEnabled = false
        poser?.reset()
    }

    func updateCraft(_ f: FlightController, view: FlightView, course: Course, dt: Double = 1.0 / 90) {
        guard f.phase != .idle else { return }
        let com = Float(craftModel.map { -$0.position.y } ?? 2)
        craftHolder.position = rk(f.position) + [0, com, 0]
        let nose = Vec3(cos(f.pitch) * sin(f.yaw), cos(f.pitch) * cos(f.yaw), sin(f.pitch))
        let dir = simd_normalize(rk(nose))
        craftHolder.orientation = simd_quatf(from: [0, 1, 0], to: dir)
        if let plume {
            plume.isEnabled = f.throttle > 0 && f.phase != .finished
            plume.scale = [1, Float(0.4 + f.throttle), 1]
        }
        // Canopies hang above the craft, opposite to gravity.
        let up = craftHolder.orientation.inverse.act([0, 1, 0])
        let rigged = poser?.hasRiggedChute ?? false
        drogue?.isEnabled = !rigged && f.chuteStage == 1
        mainChute?.isEnabled = !rigged && f.chuteStage == 2
        poser?.update(.init(flying: f.phase == .flying, altitude: f.altitude, verticalSpeed: f.verticalSpeed, speed: f.speed,
                            throttle: f.throttle, fuel: f.fuel, chuteStage: f.chuteStage, rates: f.rates, dt: dt))
        for c in [drogue, mainChute].compactMap({ $0 }) {
            c.position = up * (f.chuteStage == 2 ? 14 : 8)
            c.orientation = simd_quatf(from: [0, 1, 0], to: up)
        }
        if view == .chase {
            let target = rk(f.position)
            let k = 1 - exp(-6 * Float(min(dt, 0.1)))
            let focus = chaseFocus.map { $0 + (target - $0) * k } ?? target
            chaseFocus = focus
            root.position = -focus + [0, 1.2, -15]
        }
    }

    func applyView(_ view: FlightView, course: Course) {
        marker?.isEnabled = view == .tabletop
        switch view {
        case .ground:
            root.scale = .one
            root.position = [0, -1.6, -60]
            staticHolder.isEnabled = true
            hud?.position = [0, 1.15, -1.1]
        case .chase:
            root.scale = .one
            staticHolder.isEnabled = true
            hud?.position = [0.9, 1.1, -1.0]
        case .tabletop:
            let ext = max(course.extent.x, course.extent.y, course.extent.z)
            let s = Float(2.0 / ext)
            root.scale = .init(repeating: s)
            root.position = [0, 0.75, -0.6]
            staticHolder.isEnabled = true
            hud?.position = [-1.1, 1.1, -0.9]
        }
        hud?.orientation = view == .tabletop ? simd_quatf(angle: 0.5, axis: [0, 1, 0]) :
            (view == .chase ? simd_quatf(angle: -0.4, axis: [0, 1, 0]) : simd_quatf(angle: 0, axis: [0, 1, 0]))
    }

    /// Predicted path as a dotted ribbon coloured by speed; red marker at the predicted failure point.
    func rebuildRibbon(_ report: FlightReport?, view: FlightView) {
        ribbonHolder.children.removeAll()
        ribbonApex = report?.samples.max { $0.position.z < $1.position.z }?.position
        guard let report, !report.samples.isEmpty else { return }
        let r: Float = view == .tabletop ? 5 : 0.35
        let samples = report.samples
        let stride = max(1, samples.count / 220)
        let maxV = max(samples.map(\.speed).max() ?? 1, 1)
        let mesh = MeshResource.generateSphere(radius: r)
        var mats: [Int: UnlitMaterial] = [:]
        for i in Swift.stride(from: 0, to: samples.count, by: stride) {
            let s = samples[i]
            let bucket = Int(min(9, s.speed / maxV * 10))
            let mat = mats[bucket] ?? {
                let t = Float(bucket) / 9
                let m = UnlitMaterial(color: UIColor(red: CGFloat(0.35 + 0.65 * t), green: CGFloat(0.75 - 0.3 * t),
                                                     blue: CGFloat(1 - 0.85 * t), alpha: 1))
                mats[bucket] = m
                return m
            }()
            let e = ModelEntity(mesh: mesh, materials: [mat])
            e.position = rk(s.position) + [0, 0.5, 0]
            ribbonHolder.addChild(e)
        }
        if report.result.failure != nil, let last = samples.last {
            let e = ModelEntity(mesh: .generateSphere(radius: r * 4), materials: [PartMeshFactory.unlit(0xC8302C)])
            e.position = rk(last.position) + [0, 0.5, 0]
            ribbonHolder.addChild(e)
        }
    }
}

extension Entity {
    func withPosition(_ p: SIMD3<Float>) -> Entity { position = p; return self }
}
