import Testing
import SpacecraftCore
import FlightRunner
import Curriculum

struct AlgorithmChallengeTests {
    @Test func bothChallengesHavePlayableStartsAndPassingReferences() {
        for challenge in AlgorithmChallenge.all {
            guard let mission = Mission.named(challenge.id) else {
                Issue.record("Missing mission \(challenge.id)")
                continue
            }
            var craft = CraftDesign.rHop()
            craft.payloadMass = mission.payloadMass
            #expect(mission.blockers(for: craft).isEmpty)

            let starter = FlightPreview.run(source: challenge.starterCode, craft: craft, mission: mission)
            #expect(starter.compileError == nil)
            #expect(!starter.result.passed)

            let reference = FlightPreview.run(source: challenge.referenceCode, craft: craft, mission: mission)
            #expect(reference.compileError == nil)
            #expect(reference.faults.isEmpty)
            #expect(reference.result.passed, "\(challenge.id): \(String(describing: reference.result.failure))")
        }
    }

    @Test func predictiveGuidanceRespondsToBuildMass() {
        let challenge = AlgorithmChallenge.predictive
        let light = FlightPreview.run(source: challenge.referenceCode, craft: .rHop(payload: 20), mission: .m1p)
        let heavy = FlightPreview.run(source: challenge.referenceCode, craft: .rHop(payload: 35), mission: .m1p)
        #expect(abs(light.result.apogee - heavy.result.apogee) > 5)
    }
}
