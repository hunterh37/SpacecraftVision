import Testing
import Foundation
import simd
import SpacecraftCore
import FlightSim
import FlightCode
@testable import FlightRunner
import Curriculum

/// The path graph draws the preview and overlays the live rocket. They must be the same flight.
struct LiveMatchesPreviewTests {
    @Test(arguments: [0, 1, 2]) func liveSamplesEqualPreviewSamples(_ lessonID: Int) throws {
        let l = Lesson.all[lessonID]
        let craft: CraftDesign = lessonID == 2 ? .rGates() : .rHop()
        let preview = FlightPreview.run(source: l.referenceCode, craft: craft, mission: l.mission)

        // Live: FlightController advances the sim by whatever steps fit in each rendered frame.
        let sim = FlightSimulation(craft: craft, mission: l.mission)
        try ScriptGuidance(source: l.referenceCode).attach(to: sim)
        var rng = SplitMix64(seed: 42)
        while !sim.finished { sim.advance(steps: 1 + Int(rng.unit() * 11)) }

        #expect(sim.samples.count == preview.samples.count)
        var worst = 0.0
        for (a, b) in zip(sim.samples, preview.samples) { worst = max(worst, simd_length(a.position - b.position), abs(a.t - b.t)) }
        #expect(worst == 0, "live and preview diverged by \(worst) m")
        #expect(sim.result?.apogee == preview.result.apogee)
    }
}
