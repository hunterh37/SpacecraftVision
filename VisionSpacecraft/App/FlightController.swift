import SwiftUI
import SpacecraftCore
import FlightSim
import FlightCode
import FlightRunner
import Curriculum

/// Live flight: steps FlightSim at 240 Hz scaled by the time-scale buttons, from the immersive scene's frame updates.
@MainActor @Observable
final class FlightController {
    enum Phase: Equatable { case idle, flying, paused, finished }

    private(set) var phase: Phase = .idle
    var timeScale: Double = 1
    private(set) var sim: FlightSimulation?
    private var guidance: ScriptGuidance?
    private var accumulator = 0.0
    private var slowMoUntil: Double?
    private(set) var launchError: String?
    var onFinish: ((FlightReport, [CommandRecord]) -> Void)?

    // Telemetry snapshot for the HUD (specs/03).
    private(set) var altitude = 0.0
    private(set) var speed = 0.0
    private(set) var throttle = 0.0
    private(set) var fuel = 0.0
    private(set) var energy = 0.0
    private(set) var time = 0.0
    private(set) var logLine = ""
    private(set) var gates = 0
    private(set) var position = Vec3.zero
    private(set) var pitch = Double.pi / 2
    private(set) var yaw = 0.0
    private(set) var chuteStage = 0
    private(set) var lastFault: String?
    /// Increments each launch so the scene can reset entities.
    private(set) var launchID = 0

    func launch(source: String, craft: CraftDesign, mission: Mission) {
        launchError = nil
        if let b = mission.blockers(for: craft).first {
            launchError = "Cannot launch. \(b.title). \(b.body)"
            return
        }
        let sim = FlightSimulation(craft: craft, mission: mission)
        do {
            let g = try ScriptGuidance(source: source)
            g.attach(to: sim)
            guidance = g
        } catch let e as CompileError {
            launchError = "Code does not compile. Line \(e.line): \(e.message)"
            return
        } catch {
            launchError = "\(error)"
            return
        }
        self.sim = sim
        accumulator = 0
        slowMoUntil = nil
        timeScale = 1
        launchID += 1
        phase = .flying
        snapshot()
    }

    func clearError() { launchError = nil }

    func abort() {
        guard sim != nil else { return }
        finish()
    }

    func togglePause() {
        if phase == .flying { phase = .paused } else if phase == .paused { phase = .flying }
    }

    func reset() {
        sim = nil; guidance = nil; phase = .idle
        position = .zero; pitch = .pi / 2; yaw = 0; chuteStage = 0
        launchID += 1
    }

    /// Advance by real seconds.
    func tick(_ dt: Double) {
        guard phase == .flying, let sim else { return }
        var scale = timeScale
        if let until = slowMoUntil {
            scale = 0.1
            if sim.time >= until || sim.finished { slowMoUntil = nil; finish(); return }
        }
        accumulator += min(dt, 0.1) * scale * FlightSimulation.physicsRate
        let n = Int(accumulator)
        accumulator -= Double(n)
        sim.advance(steps: n)
        snapshot()
        if sim.finished && slowMoUntil == nil {
            if sim.result?.passed == false { slowMoUntil = sim.time + 0.15 } else { finish() }
        }
    }

    private func snapshot() {
        guard let sim else { return }
        altitude = sim.altitude
        speed = simd_len(sim.velocity)
        throttle = sim.effectiveThrottle
        fuel = sim.fuelFraction
        energy = sim.energyFraction
        time = sim.time
        logLine = sim.lastLog
        gates = sim.gatesPassed
        position = sim.position
        pitch = sim.pitch
        yaw = sim.yaw
        chuteStage = sim.chuteStage
        lastFault = sim.faultMessages.last.map { "Line \($0.line): \($0.message)" }
    }

    private func finish() {
        guard let sim else { return }
        let result: FlightResult
        if let r = sim.result { result = r } else {
            result = FlightResult(passed: false,
                                  failure: FlightFailure(key: "abort", title: "Aborted", body: "Flight aborted at \(Int(sim.time)) s.",
                                                         time: sim.time, tick: sim.tick, value: 0, limit: 0, line: nil),
                                  duration: sim.time, apogee: sim.apogee, fuelUsed: 0, gatesPassed: sim.gatesPassed,
                                  minClearance: sim.minClearance, pitchRMSDeg: sim.pitchRMS, score: 0)
        }
        phase = .finished
        snapshot()
        let report = FlightPreview.report(sim, result)
        let cmds = guidance?.commands.map { CommandRecord(t: $0.t, name: $0.name, value: $0.value, altitude: $0.altitude, vz: $0.vz) } ?? []
        onFinish?(report, cmds)
    }
}
