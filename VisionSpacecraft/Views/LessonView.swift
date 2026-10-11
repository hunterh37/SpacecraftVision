import SwiftUI
import LabUI
import Curriculum
import SpacecraftCore

/// Five-stage lesson flow (specs/06): concept narration, pseudocode block ordering, implement in the code
/// window, run in the range, then plots, hidden tests, the analysis question and stars.
struct LessonView: View {
    let lesson: Lesson
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @State private var card = 0
    @State private var pool: [String] = []
    @State private var placed: [String] = []
    @State private var checkResult: Bool?

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 16) {
            LabHeader(kicker: "Lesson \(String(format: "%02d", lesson.id))", title: lesson.title, tint: Brand.telemetry)
            LabTabs(items: LessonStage.allCases, selection: $model.lessonStage, title: { $0.title })
            ScrollView {
                Group {
                    switch model.lessonStage {
                    case .concept: concept
                    case .pseudocode: pseudocode
                    case .implement: implement
                    case .run: run
                    case .analyze: analyze
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(Lab.soft(16))
                .padding(20)
                .labPanel(corner: 28, tint: Brand.telemetry, variant: .tide, aurora: 0.25)
            }
            HStack {
                Spacer()
                if let next = LessonStage(rawValue: model.lessonStage.rawValue + 1) {
                    Button("NEXT") { model.lessonStage = next }.buttonStyle(BrandButtonStyle())
                }
            }
        }
        .padding(32)
        .labWindow(tint: Brand.telemetry, variant: .tide, aurora: 0.16)
        .navigationTitle("\(lesson.id). \(lesson.title)")
        .onDisappear { if model.openLesson?.id == lesson.id { model.openLesson = nil } }
        .onChange(of: model.pseudocodeDemo) {
            placed = lesson.blocks
            pool = lesson.distractors
            checkResult = true
            model.pseudocodePassed.insert(lesson.id)
        }
        .onAppear {
            model.openLesson = lesson
            if model.lesson?.id != lesson.id || model.mission.id != lesson.missionId { model.select(lesson: lesson) }
            resetBlocks()
        }
    }

    // MARK: Stages

    var concept: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabCaption(lesson.subtitle)
            Text(lesson.narration[card]).font(Lab.soft(20))
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                .labCard(padding: 20)
            HStack(spacing: 10) {
                Button { card = max(0, card - 1) } label: { Image(systemName: "backward.fill") }
                    .buttonStyle(LabIconButton()).disabled(card == 0)
                Text("\(card + 1) / \(lesson.narration.count)").font(Lab.mono(13)).foregroundStyle(Lab.muted)
                Button { card = min(lesson.narration.count - 1, card + 1) } label: { Image(systemName: "forward.fill") }
                    .buttonStyle(LabIconButton()).disabled(card == lesson.narration.count - 1)
            }
        }
    }

    var pseudocode: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tap the blocks in the order the algorithm runs them. One block does not belong.").foregroundStyle(Lab.muted)
            LabCaption("Your algorithm")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(placed.enumerated()), id: \.offset) { i, b in
                    Button { placed.remove(at: i); pool.append(b); checkResult = nil } label: {
                        Text("\(i + 1). \(b)").font(Lab.mono(14)).foregroundStyle(Lab.ink).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                if placed.isEmpty { Text("Empty").foregroundStyle(Lab.faint) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .labCard(tint: Brand.telemetry, corner: 16, padding: 12)
            LabCaption("Blocks", tint: Brand.trajectory)
            FlowBlocks(items: pool) { b in
                pool.removeAll { $0 == b }; placed.append(b); checkResult = nil
            }
            HStack {
                Button("Check") {
                    checkResult = placed == lesson.blocks
                    if checkResult == true { model.pseudocodePassed.insert(lesson.id) }
                }
                .buttonStyle(LabPrimaryButton())
                Button("Shuffle again") { resetBlocks() }.buttonStyle(LabGhostButton())
                if let ok = checkResult {
                    LabCaption(ok ? "Done" : "Try again", tint: ok ? Brand.telemetry : Brand.ignition)
                }
            }
        }
    }

    var implement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The starter code holds the pseudocode as comments and stubs marked TODO. Fill them in.")
            Text("Mission \(lesson.mission.id): \(goalText)").font(Lab.soft(14)).foregroundStyle(Lab.muted)
            Button("Open code editor", systemImage: "chevron.left.forwardslash.chevron.right") { openWindow(id: WindowID.code) }
                .buttonStyle(BrandButtonStyle(tint: Brand.telemetry))
            Button("Open workshop", systemImage: "wrench.and.screwdriver") {
                Task { await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.workshop) }
                openWindow(id: WindowID.parts)
            }
            .buttonStyle(LabGhostButton())
            previewStatus
        }
    }

    var run: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fly the craft with your code in the life-size range.")
            previewStatus
            Button("Launch in range", systemImage: "flame.fill") {
                Task {
                    await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.range)
                    model.launch()
                }
            }
            .buttonStyle(BrandButtonStyle())
            if let r = model.lastReport { ResultCard(report: r) }
        }
    }

    var analyze: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let r = model.lastReport {
                FlightPlots(report: r, ghosts: Array(model.reports.dropLast().suffix(1)), compact: false)
            } else {
                Text("Run a flight first. Plots appear here.").foregroundStyle(Lab.muted)
            }
            LabCaption("Question", tint: Brand.trajectory)
            Text(lesson.question.prompt).font(Lab.soft(17))
            ForEach(Array(lesson.question.options.enumerated()), id: \.offset) { i, o in
                Button {
                    model.answers[lesson.id] = i
                } label: {
                    HStack {
                        Image(systemName: model.answers[lesson.id] == i ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(model.answers[lesson.id] == i ? Brand.telemetry : Lab.faint)
                        Text(o).foregroundStyle(Lab.ink).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .labCard(tint: model.answers[lesson.id] == i ? Brand.telemetry : Lab.edge, corner: 14, padding: 12)
                }
                .buttonStyle(.plain)
            }
            if let a = model.answers[lesson.id] {
                Text(a == lesson.question.answer ? "Correct." : "Not this one. Compare the plots of two runs.")
                    .foregroundStyle(a == lesson.question.answer ? Brand.telemetry : Brand.ignition)
            }
            if let g = model.grade(lesson) {
                LabCaption("Hidden tests", tint: Brand.ignition).padding(.top, 6)
                ForEach(g.tests) { t in
                    Label(t.name, systemImage: t.passed ? "checkmark.circle" : "xmark.circle").foregroundStyle(t.passed ? Brand.telemetry : Lab.danger)
                        .font(Lab.mono(12))
                }
                Text("SCORE \(g.score) · " + String(repeating: "★", count: g.stars) + String(repeating: "☆", count: 3 - g.stars))
                    .font(Lab.display(20)).foregroundStyle(Brand.ignition)
                Button("COMPLETE LESSON") { model.completed[lesson.id] = max(model.completed[lesson.id] ?? 0, g.stars) }
                    .buttonStyle(BrandButtonStyle())
                    .disabled(model.answers[lesson.id] == nil)
            } else if model.lastReport != nil {
                Text("The lesson completes when the mission passes. Fix the code and run again.").foregroundStyle(Lab.muted)
            }
        }
    }

    @ViewBuilder var previewStatus: some View {
        if case let .error(e) = model.compileStatus {
            LabCaption("Compile error · line \(e.line)", tint: Lab.danger)
            Text(e.message).font(Lab.mono(12)).foregroundStyle(Color(red: 1, green: 0.83, blue: 0.85))
        } else if let p = model.preview {
            if let f = p.result.failure {
                Text("Predicted: \(f.title). \(f.body)").foregroundStyle(Brand.ignition)
            } else {
                Text("Predicted: mission passed, apogee \(Int(p.result.apogee)) m.").foregroundStyle(Brand.telemetry)
            }
        }
    }

    var goalText: String {
        switch lesson.mission.goal {
        case let .hop(lo, hi, rms):
            "apogee \(Int(lo)) to \(Int(hi)) m, touchdown in the zone at 6 m/s or less" + (rms.map { ", pitch error RMS \(Int($0)) deg or less" } ?? "")
        case .gates: "pass the gates in order, then cross the finish"
        }
    }

    func resetBlocks() {
        placed = []
        checkResult = nil
        var rng = SystemRandomNumberGenerator()
        pool = (lesson.blocks + lesson.distractors).shuffled(using: &rng)
    }
}

struct FlowBlocks: View {
    let items: [String]
    let tap: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { b in
                Button { tap(b) } label: {
                    Text(b).font(Lab.mono(14))
                }
                .buttonStyle(LabGhostButton(tint: Brand.trajectory))
            }
        }
    }
}
