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
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                LabHeader("\(model.mission.id) \(model.mission.title)", caption: "Flight code · Python") {
                    HStack(spacing: 10) {
                        Button("Reset", systemImage: "arrow.counterclockwise") { if let l = currentLesson { model.workspace(for: l).resetToStarter() } else { model.resetCode() } }
                            .buttonStyle(LabSecondaryButtonStyle())
                        Button("Run", systemImage: "play.fill") {
                            Task {
                                await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.range)
                                model.launch()
                            }
                        }
                        .buttonStyle(BrandButtonStyle())
                    }
                }
                TipBanner(tip: .code)
                editor
                status
            }
            apiReference.frame(width: 300)
        }
        .padding(24)
        .labWindow()
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
            case .idle: Text("COMPILING").foregroundStyle(Brand.dim)
            case .ok: Label("COMPILED", systemImage: "checkmark.circle").foregroundStyle(Brand.telemetry)
            case let .error(e): Label("LINE \(e.line), COLUMN \(e.column): \(e.message)", systemImage: "xmark.octagon").foregroundStyle(Lab.danger)
            }
            if let p = model.preview, p.compileError == nil {
                if let f = p.result.failure {
                    Text("Preview: \(f.title) at \(String(format: "%.1f", f.time)) s. \(f.body)").foregroundStyle(Brand.ignition)
                } else {
                    Text("Preview: mission passed. Apogee \(Int(p.result.apogee)) m, \(String(format: "%.0f", p.result.duration)) s flight.").foregroundStyle(Brand.telemetry)
                }
                if let fault = p.faults.first { Text("Runtime fault: \(fault)").foregroundStyle(Lab.danger) }
            }
            if model.previewing { ProgressView().controlSize(.small) }
            if let err = model.flight.launchError { Text(err).foregroundStyle(Lab.danger) }
        }
        .font(Brand.label(12))
    }

    var apiReference: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Rectangle().fill(Brand.trajectory).frame(width: 22, height: 3).clipShape(Capsule())
                    Text("CRAFT API").font(Brand.label(11)).tracking(2.2).foregroundStyle(Brand.trajectory)
                }
                ForEach(CraftAPIReference.entries, id: \.call) { e in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(PythonSyntax.attributed(e.call, size: 13)).font(.system(size: 13, design: .monospaced))
                        Text(e.doc).font(.system(size: 12, weight: .medium)).foregroundStyle(Brand.dim)
                    }
                }
                Divider().overlay(Lab.edge.opacity(0.2))
                Text("ENTRY POINTS").font(Brand.label(10)).tracking(2).foregroundStyle(Brand.dim)
                Text("setup() runs once before launch.\nupdate(dt) runs 50 times a second, dt = 0.02 s.").font(.system(size: 12, weight: .medium)).foregroundStyle(Brand.dim)
            }
            .padding(20)
        }
        .labCard(corner: 26, tint: Brand.trajectory, variant: .tide, aurora: 0.14)
    }
}
