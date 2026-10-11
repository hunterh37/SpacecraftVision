import SwiftUI
import SpacecraftCore
import FlightSim
import FlightRunner
import Curriculum
import LabUI

/// Developer harness: renders LabUI in the visionOS simulator with real lesson data and the real tracer.
/// Choose a scene with the launch argument `-scene blocks|python|trace|error|empty` and a lesson with `-lesson 0|1|2`.
@main
struct LabPreviewApp: App {
    var body: some Scene {
        WindowGroup { PreviewRoot() }
            .defaultSize(width: 1100, height: 820)
    }
}

struct PreviewRoot: View {
    @State private var model: CodeWorkspaceModel
    @State private var errorLine: Int?
    @State private var errorText: String?
    let scene = UserDefaults.standard.string(forKey: "scene") ?? "blocks"
    let lessonIndex = UserDefaults.standard.integer(forKey: "lesson")

    init() {
        let l = Lesson.all[UserDefaults.standard.integer(forKey: "lesson")]
        let craft: CraftDesign = l.id == 2 ? .rGates() : .rHop()
        let m = CodeWorkspaceModel(lesson: l, sink: { _ in }, tracer: { src, t in
            await Task.detached { FlightTracer.trace(source: src, craft: craft, mission: l.mission, atTime: t) }.value
        })
        _model = State(initialValue: m)
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.045, blue: 0.1).ignoresSafeArea()
            CodeWorkspace(model: model, errorLine: errorLine, errorText: errorText, flightDuration: 30)
                .padding(30)
        }
        .task { await setup() }
    }

    func setup() async {
        guard let p = model.program else { return }
        switch scene {
        case "empty": break
        case "python": model.loadSolution(); model.tab = .python
        case "trace":
            model.loadSolution(); model.traceTime = l1Time(); model.tab = .trace
            await model.runTrace()
            // jump to the first step that runs a line owned by a block, so the block lights up
            if let o = model.composed?.origins, let i = model.trace?.steps.firstIndex(where: { o.indices.contains($0.line - 1) && o[$0.line - 1] != nil }) { model.traceStep = i + 1 }
        case "error":
            // pitch command before the error is measured: a real runtime fault from the real VM
            model.order = [p.solution[1], p.solution[0]] + p.solution.dropFirst(2); model.values = p.referenceValues
            let l = model.lesson
            let rep = FlightPreview.run(source: model.source, craft: l.id == 2 ? .rGates() : .rHop(), mission: l.mission)
            if let f = rep.faults.first, let line = f.split(separator: " ").dropFirst().first.flatMap({ Int($0.dropLast()) }) { errorLine = line; errorText = String(f.drop(while: { $0 != ":" }).dropFirst(2)) }
        default: model.loadSolution()
        }
    }
    func l1Time() -> Double { 3.0 }
}
