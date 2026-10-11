import Testing
import Foundation
@testable import SpacecraftCore

struct CoreTests {
    @Test func rHopMatchesReferenceTable() {
        let s = CraftDesign.rHop().stats()
        #expect(abs(s.dryMass - 309.2) < 0.01)
        #expect(abs(s.wetMass - 404.2) < 0.01)
        #expect(s.cost == 18_700)
        #expect(abs(s.twrSL - 6.05) < 0.01)
        #expect(s.partCount == 11)
    }
    @Test func rGatesTWR() {
        let s = CraftDesign.rGates().stats()
        #expect(abs(s.twrSL - 1.94) < 0.01)
    }
    @Test func centerOfMassInsideStack() {
        let c = CraftDesign.rHop()
        let s = c.stats()
        #expect(s.centerOfMass > 0 && s.centerOfMass < c.height)
        #expect(abs(c.height - 4.1) < 1e-9)
    }
    @Test func deltaV() {
        let s = CraftDesign.rHop().stats()
        let expected = 312 * g0 * log(404.2 / 309.2)
        #expect(abs(s.deltaVVac - expected) < 0.5)
    }
    @Test func blockers() {
        var c = CraftDesign.rHop()
        #expect(Mission.m1.blockers(for: c).isEmpty)
        c.stack.insert(PartInstance(partId: "fuel-tank-m"), at: 2)
        let b = Mission.m1.blockers(for: c).map(\.key)
        #expect(b.contains("fail.mass") && b.contains("fail.part-list"))
    }
}

@Test func saturnVStack() {
    let c = CraftDesign.saturnV()
    #expect(abs(c.height - 110.61) < 0.05)
    let s = c.stats()
    #expect(abs(s.wetMass - 2_936_850) < 1)
    #expect(s.hasCommand)
    #expect(c.stack.allSatisfy { PartCatalog.part($0.partId) != nil })
}
