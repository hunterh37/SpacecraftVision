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
            VStack(alignment: .leading, spacing: 14) {
                LabHeader(kicker: "\(model.mission.id) · Python", title: model.mission.title) {
                    Button("Reset", systemImage: "arrow.counterclockwise") { if let l = currentLesson { model.workspace(for: l).resetToStarter() } else { model.resetCode() } }
                        .buttonStyle(LabGhostButton())
                    Button {
                        Task {
                            await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.range)
                            model.launch()
                        }
                    } label: { Label("RUN", systemImage: "play.fill") }
                    .buttonStyle(BrandButtonStyle())
                }
                TipBanner(tip: .code)
                editor
                status
            }
            .padding(24)
            Rectangle().fill(Lab.edge.opacity(0.18)).frame(width: 1).padding(.vertical, 24)
            apiReference.frame(width: 300)
        }
        .labWindow(tint: Brand.telemetry, variant: .dusk, aurora: 0.18)
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
                    Text(challenge.strategy).font(Lab.soft(17)).foregroundStyle(Lab.ink)
                    Text(challenge.tuningHint).font(Lab.soft(14)).foregroundStyle(Lab.muted)
                }
                PythonEditor(text: Binding(get: { model.source }, set: { model.source = $0 }),
                             errorLine: model.codeProblem?.line, errorText: model.codeProblem?.text)
                FlightPathView(report: model.preview, course: model.mission.course, cursor: $challengeCursor, height: 120)
            }
            .padding(18)
            .labPanel(tint: model.codeProblem == nil ? Brand.telemetry : Lab.danger, variant: .dusk)
        }
    }

    @ViewBuilder var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch model.compileStatus {
            case .idle: LabCaption("Compiling", tint: Lab.muted)
            case .ok: LabCaption("Compiled", tint: Brand.telemetry)
            case let .error(e): LabCaption("1 error · line \(e.line):\(e.column)", tint: Lab.danger)
                Text(e.message).font(Lab.mono(12)).foregroundStyle(Color(red: 1, green: 0.83, blue: 0.85))
            }
            if let p = model.preview, p.compileError == nil {
                if let f = p.result.failure {
                    Text("Preview: \(f.title) at \(String(format: "%.1f", f.time)) s. \(f.body)").foregroundStyle(Brand.ignition)
                } else {
                    Text("Preview: mission passed. Apogee \(Int(p.result.apogee)) m, \(String(format: "%.0f", p.result.duration)) s flight.")
                        .foregroundStyle(Brand.telemetry)
                }
                if let fault = p.faults.first { Text("Runtime fault: \(fault)").foregroundStyle(Lab.danger) }
            }
            if model.previewing { ProgressView().controlSize(.small).tint(Brand.telemetry) }
            if let err = model.flight.launchError { Text(err).foregroundStyle(Lab.danger) }
        }
        .font(Lab.soft(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .labCard(tint: model.codeProblem == nil ? Lab.edge : Lab.danger, corner: 18, padding: 14)
    }

    var apiReference: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LabCaption("Craft API", tint: Brand.trajectory)
                ForEach(CraftAPIReference.entries, id: \.call) { e in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(e.call).font(Lab.mono(13)).foregroundStyle(Brand.telemetry)
                        Text(e.doc).font(Lab.soft(12)).foregroundStyle(Lab.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .labCard(corner: 14, padding: 10)
                }
                LabCaption("Entry points", tint: Brand.ignition).padding(.top, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text("setup()").font(Lab.mono(13)).foregroundStyle(Brand.telemetry)
                    Text("Runs once before launch.").font(Lab.soft(12)).foregroundStyle(Lab.muted)
                    Text("update(dt)").font(Lab.mono(13)).foregroundStyle(Brand.telemetry).padding(.top, 4)
                    Text("Runs 50 times a second, dt = 0.02 s.").font(Lab.soft(12)).foregroundStyle(Lab.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .labCard(corner: 14, padding: 10)
            }
            .padding(20)
        }
    }
}
