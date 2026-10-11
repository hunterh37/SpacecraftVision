import SwiftUI
import FlightCode
import FlightRunner
import SpacecraftCore
import Curriculum
import LabUI

/// Text-mode code editor (specs/05): monospaced source, compile status with line, preview summary,
/// craft API reference, Run and Reset to starter.
struct CodeEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @State private var challengeCursor = 3.0

    private var currentLesson: Lesson? { Lesson.all.first { $0.missionId == model.mission.id } }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(model.mission.id) \(model.mission.title)").font(.title3.bold())
                    Text("Python").font(.caption).padding(.horizontal, 8).padding(.vertical, 3).background(.thinMaterial, in: Capsule())
                    Spacer()
                    Button("Reset to starter", systemImage: "arrow.counterclockwise") { if let l = currentLesson { model.workspace(for: l).resetToStarter() } else { model.resetCode() } }
                    Button("Run", systemImage: "play.fill") {
                        Task {
                            await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.range)
                            model.launch()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                TipBanner(tip: .code)
                editor
                status
            }
            .padding(20)
            Divider()
            apiReference.frame(width: 300)
        }
        .onAppear { model.codeOpened = true }
    }

    @ViewBuilder var editor: some View {
        if let lesson = currentLesson {
            CodeWorkspace(model: model.workspace(for: lesson), errorLine: model.codeProblem?.line, errorText: model.codeProblem?.text,
                          flightDuration: model.preview?.result.duration ?? 30,
                          report: model.preview.flatMap { $0.compileError == nil ? $0 : nil }, course: lesson.mission.course, live: model.liveFlight)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if let challenge = AlgorithmChallenge.named(model.mission.id) {
                    Text(challenge.strategy).font(.headline)
                    Text(challenge.tuningHint).font(.callout).foregroundStyle(.secondary)
                }
                PythonEditor(text: Binding(get: { model.source }, set: { model.source = $0 }),
                             errorLine: model.codeProblem?.line, errorText: model.codeProblem?.text)
                FlightPathView(report: model.preview, course: model.mission.course, cursor: $challengeCursor, height: 120)
            }
        }
    }

    @ViewBuilder var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch model.compileStatus {
            case .idle: Text("Compiling").foregroundStyle(.secondary)
            case .ok: Label("Compiled", systemImage: "checkmark.circle").foregroundStyle(.green)
            case let .error(e): Label("1 error. Line \(e.line), column \(e.column): \(e.message)", systemImage: "xmark.octagon").foregroundStyle(.red)
            }
            if let p = model.preview, p.compileError == nil {
                if let f = p.result.failure {
                    Text("Preview: \(f.title) at \(String(format: "%.1f", f.time)) s. \(f.body)").foregroundStyle(.orange)
                } else {
                    Text("Preview: mission passed. Apogee \(Int(p.result.apogee)) m, \(String(format: "%.0f", p.result.duration)) s flight.")
                        .foregroundStyle(.green)
                }
                if let fault = p.faults.first { Text("Runtime fault: \(fault)").foregroundStyle(.red) }
            }
            if model.previewing { ProgressView().controlSize(.small) }
            if let err = model.flight.launchError { Text(err).foregroundStyle(.red) }
        }
        .font(.callout)
    }

    var apiReference: some View {
        List {
            Section("Craft API") {
                ForEach(CraftAPIReference.entries, id: \.call) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.call).font(.system(.callout, design: .monospaced))
                        Text(e.doc).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Entry points") {
                Text("setup() runs once before launch.\nupdate(dt) runs 50 times a second, dt = 0.02 s.").font(.caption)
            }
        }
    }
}
