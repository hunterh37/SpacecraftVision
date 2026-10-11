import SwiftUI
import LabUI
import Curriculum
import SpacecraftCore

/// Learn mode deck, a range attachment beside the pad. One stage on screen, one primary button,
/// and the scene indicators point at the part of the rocket the stage is about.
struct LessonDeckView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @State private var line = 0
    @State private var pool: [String] = []
    @State private var placed: [String] = []
    @State private var checkResult: Bool?
    @State private var picking = false

    private var lesson: Lesson { model.lesson ?? Lesson.all[0] }
    private var stage: LessonStage { model.lessonStage }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if picking { picker } else {
                stageDots
                content.frame(maxWidth: .infinity, alignment: .leading).font(Lab.soft(17))
                footer
            }
        }
        .padding(24)
        .frame(width: 560)
        .labPanel(corner: 32, tint: Brand.telemetry, variant: .tide, aurora: 0.25)
        .tint(Brand.telemetry)
        .animation(.spring(duration: 0.3), value: stage)
        .animation(.spring(duration: 0.3), value: line)
        .animation(.spring(duration: 0.3), value: picking)
        .onAppear { reset() }
        .onChange(of: model.lesson?.id) { reset() }
        .onChange(of: stage) { old, new in if new == .implement && old == .pseudocode { openCode() } }
        .onChange(of: model.flight.phase) { _, p in
            if p == .finished, stage == .run, model.lastReport != nil { model.lessonStage = .analyze }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { picking.toggle() } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LESSON \(String(format: "%02d", lesson.id)) ▾").font(Brand.label(12)).foregroundStyle(Brand.telemetry).tracking(2)
                    Text(lesson.title).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Brand.ink)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button { Task { await exit() } } label: { Image(systemName: "xmark") }
                .buttonStyle(LabIconButton())
                .accessibilityLabel("Exit Learn")
        }
    }

    private var picker: some View {
        VStack(spacing: 8) {
            ForEach(Lesson.all) { l in
                Button {
                    model.select(lesson: l)
                    model.openLesson = l
                    picking = false
                } label: {
                    HStack {
                        Text(String(format: "%02d", l.id)).font(Lab.mono(14)).foregroundStyle(Brand.telemetry)
                        Text(l.title).foregroundStyle(Lab.ink)
                        Spacer()
                        if let s = model.completed[l.id] {
                            Text(String(repeating: "★", count: s) + String(repeating: "☆", count: 3 - s)).foregroundStyle(Brand.ignition)
                        }
                    }
                    .labCard(tint: l.id == lesson.id ? Brand.telemetry : Lab.edge, corner: 14, padding: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stageDots: some View {
        HStack(spacing: 6) {
            ForEach(LessonStage.allCases) { s in
                Button { model.lessonStage = s } label: {
                    VStack(spacing: 4) {
                        Capsule().fill(s.rawValue <= stage.rawValue ? Brand.telemetry : Lab.faint.opacity(0.4)).frame(height: 4)
                        Text(short(s)).font(Brand.label(10)).tracking(1)
                            .foregroundStyle(s == stage ? Brand.ink : Lab.muted)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func short(_ s: LessonStage) -> String {
        switch s { case .concept: "IDEA"; case .pseudocode: "ORDER"; case .implement: "CODE"; case .run: "FLY"; case .analyze: "DEBRIEF" }
    }

    // MARK: Stages

    @ViewBuilder private var content: some View {
        switch stage {
        case .concept: concept
        case .pseudocode: pseudocode
        case .implement: implement
        case .run: run
        case .analyze: analyze
        }
    }

    private var concept: some View {
        let lines = lesson.narration
        let i = min(line, max(0, lines.count - 1))
        return VStack(alignment: .leading, spacing: 12) {
            Text(lesson.subtitle).font(Lab.soft(14)).foregroundStyle(Lab.muted)
            Text(lines.isEmpty ? "" : lines[i]).font(Lab.soft(21))
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                .id(i)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            HStack(spacing: 5) {
                ForEach(lines.indices, id: \.self) { k in
                    Circle().fill(k == i ? Brand.telemetry : Lab.faint.opacity(0.4)).frame(width: 7, height: 7)
                }
            }
        }
    }

    private var pseudocode: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tap blocks in run order. One does not belong.").foregroundStyle(Lab.muted)
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
            .labCard(tint: checkResult == false ? Brand.ignition : Brand.telemetry, corner: 16, padding: 12)
            FlowBlocks(items: pool) { b in
                if let k = pool.firstIndex(of: b) { pool.remove(at: k) }
                placed.append(b); checkResult = nil
                if pool.count <= lesson.distractors.count { check() }
            }
            if checkResult == false {
                Text("Order is off. Tap a placed block to send it back.").font(Lab.soft(14)).foregroundStyle(Brand.ignition)
            }
        }
    }

    private var implement: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fill the TODOs in update(dt). The dotted path in front of you re-predicts on every edit.")
            Text("Goal: \(goalText)").font(Lab.soft(14)).foregroundStyle(Lab.muted)
            prediction
            Button("Fill reference code", systemImage: "wand.and.stars") { model.source = lesson.referenceCode }
                .buttonStyle(LabGhostButton())
        }
    }

    private var run: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch model.flight.phase {
            case .flying: Text("In flight. Watch the craft on the pad ahead.")
            default: Text("Craft on the pad, code loaded. Launch when ready.")
            }
            prediction
            if !model.blockers.isEmpty {
                Text("Blocked: \(model.blockers.map(\.title).joined(separator: ", "))").font(Lab.soft(14)).foregroundStyle(Brand.ignition)
            }
        }
    }

    private var analyze: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let r = model.lastReport { ResultCard(report: r) }
            else { Text("No flight yet. Go back to Fly.").foregroundStyle(Lab.muted) }
            Text(lesson.question.prompt).font(Lab.soft(17))
            ForEach(Array(lesson.question.options.enumerated()), id: \.offset) { i, o in
                let picked = model.answers[lesson.id] == i
                Button { model.answers[lesson.id] = i } label: {
                    HStack {
                        Image(systemName: picked ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(picked ? Brand.telemetry : Lab.faint)
                        Text(o).foregroundStyle(Lab.ink).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .labCard(tint: picked ? Brand.telemetry : Lab.edge, corner: 14, padding: 10)
                }
                .buttonStyle(.plain)
            }
            if let g = model.grade(lesson) {
                Text("SCORE \(g.score) · " + String(repeating: "★", count: g.stars) + String(repeating: "☆", count: 3 - g.stars))
                    .font(Lab.display(18)).foregroundStyle(Brand.ignition)
            } else if model.lastReport != nil {
                Text("Mission not passed. Fix the code and fly again.").font(Lab.soft(14)).foregroundStyle(Brand.ignition)
            }
        }
    }

    @ViewBuilder private var prediction: some View {
        if case let .error(e) = model.compileStatus {
            Text("Line \(e.line): \(e.message)").font(Lab.mono(13)).foregroundStyle(Lab.danger)
        } else if let p = model.preview {
            if let f = p.result.failure {
                Text("Predicted: \(f.title)").foregroundStyle(Brand.ignition)
            } else {
                Text("Predicted: pass, apogee \(Int(p.result.apogee)) m").foregroundStyle(Brand.telemetry)
            }
        }
    }

    // MARK: Footer, one primary action per state

    private var footer: some View {
        HStack(spacing: 12) {
            if stage != .concept || line > 0 {
                Button { back() } label: { Image(systemName: "chevron.left") }.buttonStyle(LabIconButton())
                    .accessibilityLabel("Back")
            }
            Spacer()
            secondary
            Button(primaryTitle) { primary() }
                .buttonStyle(BrandButtonStyle())
                .disabled(primaryDisabled)
        }
    }

    @ViewBuilder private var secondary: some View {
        switch stage {
        case .pseudocode: Button("Shuffle") { reset() }.buttonStyle(LabGhostButton())
        case .implement: Button("Open code") { openCode() }.buttonStyle(LabGhostButton())
        case .run where model.flight.phase == .flying: Button("Open code") { openCode() }.buttonStyle(LabGhostButton())
        case .analyze: Button("Fly again") { model.lessonStage = .run }.buttonStyle(LabGhostButton())
        default: EmptyView()
        }
    }

    private var primaryTitle: String {
        switch stage {
        case .concept: line < lesson.narration.count - 1 ? "NEXT" : "BUILD IT"
        case .pseudocode: checkResult == true ? "WRITE CODE" : "CHECK"
        case .implement: "TO THE PAD"
        case .run: model.flight.phase == .flying ? "FLYING…" : "LAUNCH"
        case .analyze: model.grade(lesson) != nil ? (lesson.id == Lesson.all.last?.id ? "FINISH" : "NEXT LESSON") : "FLY AGAIN"
        }
    }

    private var primaryDisabled: Bool {
        switch stage {
        case .pseudocode: checkResult != true && placed.isEmpty
        case .run: model.flight.phase == .flying || !model.blockers.isEmpty
        case .analyze: model.grade(lesson) != nil && model.answers[lesson.id] == nil
        default: false
        }
    }

    private func primary() {
        switch stage {
        case .concept:
            if line < lesson.narration.count - 1 { line += 1 } else { model.lessonStage = .pseudocode }
        case .pseudocode:
            if checkResult == true { model.lessonStage = .implement } else { check() }
        case .implement:
            model.lessonStage = .run
        case .run:
            model.flightView = .ground
            model.launch()
        case .analyze:
            if let g = model.grade(lesson) {
                model.completed[lesson.id] = max(model.completed[lesson.id] ?? 0, g.stars)
                if let n = Lesson.all.first(where: { $0.id > lesson.id }) {
                    model.select(lesson: n); model.openLesson = n
                } else { Task { await exit() } }
            } else { model.lessonStage = .run }
        }
    }

    private func back() {
        if stage == .concept { line = max(0, line - 1); return }
        if let p = LessonStage(rawValue: stage.rawValue - 1) {
            model.lessonStage = p
            if p == .concept { line = max(0, lesson.narration.count - 1) }
        }
    }

    private func check() {
        checkResult = placed == lesson.blocks
        if checkResult == true { model.pseudocodePassed.insert(lesson.id) }
    }

    private func openCode() {
        model.codeOpened = true
        openWindow(id: WindowID.code)
    }

    private func reset() {
        line = 0
        placed = []
        checkResult = model.pseudocodePassed.contains(lesson.id) && stage != .pseudocode ? true : nil
        var rng = SystemRandomNumberGenerator()
        pool = (lesson.blocks + lesson.distractors).shuffled(using: &rng)
    }

    private func exit() async {
        model.learnActive = false
        model.openLesson = nil
        openWindow(id: WindowID.main)
        await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).close()
    }

    private var goalText: String {
        switch lesson.mission.goal {
        case let .hop(lo, hi, _): "apogee \(Int(lo))–\(Int(hi)) m, land in the zone ≤ 6 m/s"
        case .gates: "pass the gates in order, then the finish"
        case .climb, .capstone: "climb inside the corridor to the finish"
        }
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
