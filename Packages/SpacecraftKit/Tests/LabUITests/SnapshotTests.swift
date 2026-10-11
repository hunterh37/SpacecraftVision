import Testing
import SwiftUI
import Foundation
import SpacecraftCore
import FlightSim
import FlightRunner
import Curriculum
@testable import LabUI

#if canImport(AppKit)
import AppKit

/// Renders the views to PNG so the look can be reviewed without a simulator. Output dir: $LAB_SNAPSHOT_DIR.
@MainActor
struct SnapshotTests {
    func render<V: View>(_ view: V, name: String, size: CGSize) throws {
        guard let dir = ProcessInfo.processInfo.environment["LAB_SNAPSHOT_DIR"] else { return }
        let r = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        r.scale = 2
        guard let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
            Issue.record("could not render \(name)"); return
        }
        try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
    }

    @Test func blocksPanel() throws {
        let l = Lesson.all[0]; let p = try #require(l.blockProgram)
        struct Host: View {
            let p: BlockProgram
            @State var order: [String]; @State var values: [String: Double]
            var body: some View { BlockComposer(program: p, order: $order, values: $values).padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).labPanel(variant: .tide) }
        }
        try render(Host(p: p, order: p.solution, values: p.referenceValues), name: "blocks-l0", size: CGSize(width: 760, height: 620))
        let p2 = try #require(Lesson.all[2].blockProgram)
        try render(Host(p: p2, order: p2.solution, values: p2.referenceValues), name: "blocks-l2", size: CGSize(width: 760, height: 700))
    }

    @Test func tracePanel() throws {
        let l = Lesson.all[1]; let p = try #require(l.blockProgram)
        let c = p.compose(order: p.solution, values: p.referenceValues)
        let t = FlightTracer.trace(source: c.source, craft: .rHop(), mission: l.mission, atTime: 3.0)
        struct Host: View {
            let t: TraceReport; let c: ComposedSource; @State var step = 9
            var body: some View { TraceView(report: t, source: c.source, origins: c.origins, step: $step).padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).labPanel() }
        }
        try render(Host(t: t, c: c), name: "trace-l1", size: CGSize(width: 760, height: 760))
    }

    @Test func codeWithError() throws {
        let src = "def steer(craft, obstacles, goal):\n    goal_angle = wrap_angle(math.atan2(goal.y - craft.y, goal.x - craft.x) - craft.heading)\n    best_angle = 0\n    for deg in range(-75, 76, 15):\n        angle = math.radians(deg)\n        dist = cast_ray(craft, obstacles, angle)\n    return max(-1, min(1, best_angel / 0.5))\n"
        try render(CodeSurface(source: src, errorLine: 7, errorText: "NameError: name 'best_angel' is not defined. Did you mean: 'best_angle'?").padding(24).labPanel(), name: "code-error", size: CGSize(width: 760, height: 360))
    }
}
#endif
