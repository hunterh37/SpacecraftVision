import Testing
import Foundation
@testable import FlightSim
import SpacecraftCore

final class HopController: FlightGuidance {
    let cutoff: Double
    var phase = 0
    init(cutoff: Double) { self.cutoff = cutoff }
    var activeLine: Int? { nil }
    func setup(_ sim: FlightSimulation) -> GuidanceTickResult { sim.setThrottle(1); return .ok }
    func update(_ sim: FlightSimulation, dt: Double) -> GuidanceTickResult {
        switch phase {
        case 0: if sim.altitude >= cutoff { sim.setThrottle(0); phase = 1 }
        case 1: if sim.velocity.z < 0 { sim.stage(); phase = 2 }
        case 2: if sim.altitude < 250 { sim.stage(); phase = 3 }
        default: break
        }
        return .ok
    }
}

final class BurnController: FlightGuidance {
    var activeLine: Int? { nil }
    func setup(_ sim: FlightSimulation) -> GuidanceTickResult { sim.setThrottle(1); return .ok }
    func update(_ sim: FlightSimulation, dt: Double) -> GuidanceTickResult { .ok }
}

struct FlightSimTests {
    @Test func rHopApogeeAtReferenceCutoff() {
        let sim = FlightSimulation(craft: .rHop(), mission: .m1)
        sim.guidance = HopController(cutoff: 360)
        let r = sim.runToEnd()
        print("apogee", r.apogee, r.failure?.title ?? "pass", r.duration)
        #expect(abs(r.apogee - 1092) / 1092 < 0.02)
        #expect(r.passed)
    }

    @Test func cutoffWindowEdges() {
        for (cut, expectPass) in [(250.0, false), (340.0, true), (400.0, true)] {
            let sim = FlightSimulation(craft: .rHop(), mission: .m1)
            sim.guidance = HopController(cutoff: cut)
            let r = sim.runToEnd()
            #expect(r.passed == expectPass, "cutoff \(cut) apogee \(r.apogee)")
            if !expectPass { #expect(r.failure?.key == "fail.apogee") }
        }
    }

    @Test func vacuumBurnMatchesTsiolkovsky() {
        let sim = FlightSimulation(craft: .rHop(fuelLoad: 0.5), mission: .m2)
        sim.vacuum = true
        sim.guidance = BurnController()
        let m0 = sim.mass
        var tBurn = 0.0
        while sim.propellant > 0 && !sim.finished { sim.step(); tBurn = sim.time }
        let mf = sim.mass
        let e = PartCatalog["engine-liquid-small"].engine!
        // Gravity loss with g at mean altitude.
        let gMean = 3.986e14 / pow(6_371_000 + sim.altitude / 2, 2)
        let expected = e.ispVac * g0 * log(m0 / mf) - gMean * tBurn
        #expect(abs(sim.velocity.z - expected) / expected < 0.005, "v \(sim.velocity.z) vs \(expected)")
    }

    @Test func lowThrustFailsLaunchTWR() {
        var craft = CraftDesign.rHop(fuelLoad: 1.0)
        craft.payloadMass = 2000
        let sim = FlightSimulation(craft: craft, mission: .m2)
        sim.guidance = BurnController()
        let r = sim.runToEnd()
        #expect(r.failure?.key == "fail.launch-twr")
    }

    @Test func noCutoffLeavesCorridorOrOvershoots() {
        let sim = FlightSimulation(craft: .rHop(), mission: .m1)
        sim.guidance = BurnController()
        let r = sim.runToEnd()
        #expect(!r.passed)
    }

    @Test func noParachuteCrashes() {
        let sim = FlightSimulation(craft: .rHop(), mission: .m1)
        sim.guidance = HopController(cutoff: -1) // throttle cut at once? cutoff below: immediate cut
        let r = sim.runToEnd()
        #expect(!r.passed)
    }

    @Test func determinism() {
        func run() -> [FlightSample] {
            let sim = FlightSimulation(craft: .rHop(), mission: .m1w, seed: 7)
            sim.guidance = HopController(cutoff: 360)
            _ = sim.runToEnd(); return sim.samples
        }
        #expect(run() == run())
    }

    @Test func atmosphereSeaLevel() {
        let a = Atmosphere.at(altitude: 0)
        #expect(abs(a.density - 1.225) < 0.001)
        let b = Atmosphere.at(altitude: 11_000)
        #expect(abs(b.pressure - 22_632) < 30)
    }
}
