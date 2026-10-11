import Testing
import Foundation
@testable import SpacecraftCore

struct AssemblyTests {
    @Test func fullPlanRebuildsCraft() {
        for c in [CraftDesign.rHop(), .rGates(), .saturnV()] {
            let p = AssemblyPlan(c)
            #expect(p.craft(upTo: p.count) == c)
            #expect(p.progress(of: c) == p.count)
        }
    }
    @Test func buildsBottomUp() {
        let c = CraftDesign.rHop(), p = AssemblyPlan(c)
        #expect(p.steps.first?.partId == "engine-liquid-small")
        #expect(p.steps[3].partId == "nose-cone")
        #expect(p.steps.count == 8)
        // Fins mount on the engine, which is placed first among radial parents.
        #expect(p.steps[4].partId == "fin-trapezoid")
    }
    @Test func partialStackKeepsBottom() {
        let c = CraftDesign.rHop(), p = AssemblyPlan(c)
        for k in 1...4 {
            let partial = p.craft(upTo: k)
            let spans = partial.stackSpans, full = c.stackSpans
            for (i, inst) in partial.stack.enumerated() {
                let j = c.stack.firstIndex { $0.id == inst.id }!
                #expect(abs(spans[i].bottom - full[j].bottom) < 1e-9)
            }
            #expect(p.progress(of: partial) == k)
        }
    }
    @Test func placementMatchesSpans() {
        let c = CraftDesign.rHop(), p = AssemblyPlan(c)
        let nose = p.steps[3]
        #expect(abs(p.placement(of: nose).y - c.stackSpans[0].bottom) < 1e-9)
        let fins = p.steps[4]
        #expect(p.placement(of: fins).angles.count == 4)
    }
}
