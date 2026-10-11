import SwiftUI
import LabUI
import Curriculum
import SpacecraftCore
import FlightRunner

/// One lesson in three steps. Code: the block workspace, straight away. Launch: forecast and fly. Review: results, plots,
/// and only now the explanation (concept narration and the pseudocode the blocks implement).
struct LessonView: View {
    let lesson: Lesson
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @State private var card = 0
    @State private var cursor = 3.0

    private static let stages: [LessonStage] = [.implement, .run, .analyze]
    private static let titles = ["Code", "Launch", "Review"]
    private var stageIndex: Binding<Int> {
        Binding(get: { Self.stages.firstIndex(of: model.lessonStage) ?? 0 }, set: { model.lessonStage = Self.stages[$0] })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LabHeader(lesson.title, caption: "Lesson \(lesson.id + 1) · \(lesson.subtitle)", onBack: { dismiss() }) {
                LabStagePicker(titles: Self.titles, selection: stageIndex)
            }
            switch model.lessonStage {
            case .run: launchStage
            case .analyze: reviewStage
            default: codeStage
            }
        }
        .padding(28)
        .labWindow()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onAppear {
            if model.lesson?.id != lesson.id || model.mission.id != lesson.missionId { model.select(lesson: lesson) }
            if ![.implement, .run, .analyze].contains(model.lessonStage) { model.lessonStage = .implement }
        }
    }

    // MARK: Code

    private var codeStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            CodeWorkspace(model: model.workspace(for: lesson), errorLine: model.codeProblem?.line, errorText: model.codeProblem?.text,
                          flightDuration: model.preview?.result.duration ?? 30,
                          report: model.preview.flatMap { $0.compileError == nil ? $0 : nil }, course: lesson.mission.course, live: nil, chrome: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 14) {
                prediction.frame(maxWidth: .infinity, alignment: .leading)
                Button("Launch") { model.lessonStage = .run }.buttonStyle(BrandButtonStyle())
            }
        }
    }

    // MARK: Launch

    private var launchStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                FlightPathView(report: model.preview.flatMap { $0.compileError == nil ? $0 : nil }, course: lesson.mission.course, live: model.liveFlight,
                               cursor: $cursor, height: 260)
                Text("Goal: \(goalText)").font(.system(size: 14, weight: .medium)).foregroundStyle(Brand.dim)
            }
            .padding(20).labCard(corner: 26, tint: Brand.telemetry, aurora: 0.2)
            prediction
            HStack(spacing: 12) {
                Button("Launch in range", systemImage: "flame.fill") {
                    Task {
                        await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.range)
                        model.launch()
                    }
                }
                .buttonStyle(BrandButtonStyle())
                Button("Back to code") { model.lessonStage = .implement }.buttonStyle(LabSecondaryButtonStyle())
                Spacer()
                if model.lastReport != nil { Button("See results") { model.lessonStage = .analyze }.buttonStyle(LabSecondaryButtonStyle(tint: Brand.ignition)) }
            }
            if let r = model.lastReport { ResultCard(report: r) }
            Spacer(minLength: 0)
        }
    }

    // MARK: Review

    private var reviewStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let r = model.lastReport {
                    ResultCard(report: r)
                    FlightPlots(report: r, ghosts: Array(model.reports.dropLast().suffix(1)), compact: true)
                } else {
                    Text("Launch a flight first. Results and plots appear here.").font(.system(size: 16, weight: .medium)).foregroundStyle(Brand.dim)
                        .padding(20).frame(maxWidth: .infinity, alignment: .leading).labCard(corner: 22)
                }
                howItWorks
                question
                grading
            }
            .padding(.bottom, 8)
        }
    }

    /// The explanation that used to come first: narration cards beside the blocks that implement it.
    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("How it works", tint: Brand.trajectory)
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(lesson.narration[card]).font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundStyle(Brand.ink)
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    HStack(spacing: 10) {
                        Button { card = max(0, card - 1) } label: { Image(systemName: "chevron.left") }.buttonStyle(LabSecondaryButtonStyle()).disabled(card == 0)
                        HStack(spacing: 6) { ForEach(lesson.narration.indices, id: \.self) { i in Capsule().fill(i == card ? Brand.trajectory : Color.white.opacity(0.25)).frame(width: i == card ? 18 : 6, height: 6) } }
                        Button { card = min(lesson.narration.count - 1, card + 1) } label: { Image(systemName: "chevron.right") }.buttonStyle(LabSecondaryButtonStyle()).disabled(card == lesson.narration.count - 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let p = lesson.blockProgram {
                    BlockComposer(program: p, order: .constant(p.solution), values: .constant(p.referenceValues), readOnly: true)
                        .frame(maxWidth: 420, alignment: .leading)
                }
            }
        }
        .padding(22).labCard(corner: 26, tint: Brand.trajectory, variant: .tide, aurora: 0.18)
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Check your understanding", tint: Brand.ignition)
            Text(lesson.question.prompt).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(Brand.ink)
            ForEach(Array(lesson.question.options.enumerated()), id: \.offset) { i, o in
                let picked = model.answers[lesson.id] == i
                Button { model.answers[lesson.id] = i } label: {
                    HStack(spacing: 12) {
                        Image(systemName: picked ? "largecircle.fill.circle" : "circle").foregroundStyle(picked ? Brand.ignition : Brand.dim)
                        Text(o).font(.system(size: 16, weight: .medium)).foregroundStyle(Brand.ink).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .labCard(corner: 16, tint: picked ? Brand.ignition : Brand.telemetry, aurora: 0.06)
                    .overlay { if picked { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Brand.ignition, lineWidth: 1.5) } }
                }
                .buttonStyle(.plain)
            }
            if let a = model.answers[lesson.id] {
                Text(a == lesson.question.answer ? "Correct." : "Not this one. Compare the plots of two runs.")
                    .font(Brand.label(13)).foregroundStyle(a == lesson.question.answer ? Brand.telemetry : Brand.ignition)
            }
        }
        .padding(22).labCard(corner: 26, tint: Brand.ignition, variant: .ember, aurora: 0.14)
    }

    @ViewBuilder private var grading: some View {
        if let g = model.grade(lesson) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(g.tests) { t in
                    Label(t.name, systemImage: t.passed ? "checkmark.circle" : "xmark.circle").font(Brand.label(12))
                        .foregroundStyle(t.passed ? Brand.telemetry : Lab.danger)
                }
                HStack {
                    Text("Score \(g.score)  ·  \(g.stars) of 3 stars").font(Brand.display(20)).foregroundStyle(Brand.ink)
                    Spacer()
                    Button("Complete lesson") { model.completed[lesson.id] = max(model.completed[lesson.id] ?? 0, g.stars) }
                        .buttonStyle(BrandButtonStyle(tint: Brand.telemetry)).disabled(model.answers[lesson.id] == nil)
                }
            }
            .padding(22).labCard(corner: 26, tint: Brand.telemetry, aurora: 0.16)
        } else if model.lastReport != nil {
            Text("The lesson completes when the mission passes. Fix the code and fly again.").font(.system(size: 15, weight: .medium)).foregroundStyle(Brand.dim)
        }
    }

    // MARK: Shared

    private func sectionLabel(_ s: String, tint: Color) -> some View {
        HStack(spacing: 8) { Rectangle().fill(tint).frame(width: 22, height: 3).clipShape(Capsule()); Text(s.uppercased()).font(Brand.label(11)).tracking(2.2).foregroundStyle(tint) }
    }

    /// The simulator's forecast of the current code, in one line.
    @ViewBuilder private var prediction: some View {
        if case let .error(e) = model.compileStatus {
            Label("Line \(e.line): \(e.message)", systemImage: "xmark.octagon").font(Brand.label(13)).foregroundStyle(Lab.danger)
        } else if let p = model.preview {
            if let f = p.result.failure {
                Label("Forecast: \(f.title). \(f.body)", systemImage: "exclamationmark.triangle").font(Brand.label(13)).foregroundStyle(Brand.ignition)
            } else {
                Label("Forecast: mission passes, apogee \(Int(p.result.apogee)) m.", systemImage: "checkmark.seal").font(Brand.label(13)).foregroundStyle(Brand.telemetry)
            }
        }
    }

    private var goalText: String {
        switch lesson.mission.goal {
        case let .hop(lo, hi, rms):
            "apogee \(Int(lo)) to \(Int(hi)) m, touchdown in the zone at 6 m/s or less" + (rms.map { ", pitch error RMS \(Int($0)) deg or less" } ?? "")
        case .gates: "pass the gates in order, then cross the finish"
        }
    }
}
