import SwiftUI
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
            Picker("Stage", selection: $model.lessonStage) {
                ForEach(LessonStage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
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
            }
            HStack {
                Spacer()
                if let next = LessonStage(rawValue: model.lessonStage.rawValue + 1) {
                    Button("Next") { model.lessonStage = next }.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
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
            Text(lesson.subtitle).font(.title2)
            Text(lesson.narration[card]).font(.title3).padding(20)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            HStack {
                Button("Back") { card = max(0, card - 1) }.disabled(card == 0)
                Text("\(card + 1) / \(lesson.narration.count)").monospacedDigit()
                Button("Next line") { card = min(lesson.narration.count - 1, card + 1) }.disabled(card == lesson.narration.count - 1)
            }
        }
    }

    var pseudocode: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tap the blocks in the order the algorithm runs them. One block does not belong.").font(.callout)
            Text("Your algorithm").font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(placed.enumerated()), id: \.offset) { i, b in
                    Button { placed.remove(at: i); pool.append(b); checkResult = nil } label: {
                        Text("\(i + 1). \(b)").font(.system(.callout, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if placed.isEmpty { Text("Empty").foregroundStyle(.secondary) }
            }
            .padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            Text("Blocks").font(.headline)
            FlowBlocks(items: pool) { b in
                pool.removeAll { $0 == b }; placed.append(b); checkResult = nil
            }
            HStack {
                Button("Check") {
                    checkResult = placed == lesson.blocks
                    if checkResult == true { model.pseudocodePassed.insert(lesson.id) }
                }
                .buttonStyle(.borderedProminent)
                Button("Shuffle again") { resetBlocks() }
                if let ok = checkResult {
                    Text(ok ? "Done." : "Try again.").foregroundStyle(ok ? .green : .orange)
                }
            }
        }
    }

    var implement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The starter code holds the pseudocode as comments and stubs marked TODO. Fill them in.")
            Text("Mission \(lesson.mission.id): \(goalText)").font(.callout).foregroundStyle(.secondary)
            Button("Open code editor", systemImage: "chevron.left.forwardslash.chevron.right") { openWindow(id: WindowID.code) }
                .buttonStyle(.borderedProminent)
            Button("Open workshop", systemImage: "wrench.and.screwdriver") {
                Task { await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.workshop) }
                openWindow(id: WindowID.parts)
            }
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
            .buttonStyle(.borderedProminent)
            if let r = model.lastReport { ResultCard(report: r) }
        }
    }

    var analyze: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let r = model.lastReport {
                FlightPlots(report: r, ghosts: Array(model.reports.dropLast().suffix(1)), compact: false)
            } else {
                Text("Run a flight first. Plots appear here.").foregroundStyle(.secondary)
            }
            Text(lesson.question.prompt).font(.headline)
            ForEach(Array(lesson.question.options.enumerated()), id: \.offset) { i, o in
                Button {
                    model.answers[lesson.id] = i
                } label: {
                    HStack {
                        Image(systemName: model.answers[lesson.id] == i ? "largecircle.fill.circle" : "circle")
                        Text(o).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if let a = model.answers[lesson.id] {
                Text(a == lesson.question.answer ? "Correct." : "Not this one. Compare the plots of two runs.")
                    .foregroundStyle(a == lesson.question.answer ? .green : .orange)
            }
            if let g = model.grade(lesson) {
                Divider()
                ForEach(g.tests) { t in
                    Label(t.name, systemImage: t.passed ? "checkmark.circle" : "xmark.circle").foregroundStyle(t.passed ? .green : .red)
                        .font(.caption.monospaced())
                }
                Text("Score \(g.score). \(g.stars) of 3 stars").font(.title3.bold())
                Button("Complete lesson") { model.completed[lesson.id] = max(model.completed[lesson.id] ?? 0, g.stars) }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.answers[lesson.id] == nil)
            } else if model.lastReport != nil {
                Text("The lesson completes when the mission passes. Fix the code and run again.").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder var previewStatus: some View {
        if case let .error(e) = model.compileStatus {
            Text("Compile error, line \(e.line): \(e.message)").foregroundStyle(.red)
        } else if let p = model.preview {
            if let f = p.result.failure {
                Text("Predicted: \(f.title). \(f.body)").foregroundStyle(.orange)
            } else {
                Text("Predicted: mission passed, apogee \(Int(p.result.apogee)) m.").foregroundStyle(.green)
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
                    Text(b).font(.system(.callout, design: .monospaced)).padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
