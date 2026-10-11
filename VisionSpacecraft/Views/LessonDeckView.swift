import SwiftUI
import LabUI
import Curriculum
import SpacecraftCore
import FlightRunner

/// Learn mode deck, a resizable window shown while the range is open. One stage on screen, one primary button,
/// and the scene indicators point at the part of the rocket the stage is about.
struct LessonDeckView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @State private var line = 0
    @State private var pool: [String] = []
    @State private var placed: [String] = []
    @State private var checkResult: Bool?
    @State private var picking = false
    @State private var demos = false
    @State private var pathCursor = 3.0

    private var lesson: Lesson { model.lesson ?? Lesson.all[0] }
    private var stage: LessonStage { model.lessonStage }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if picking { picker } else if demos { LessonDemoPanel(lesson: lesson) { demos = false } } else {
                stagePicker
                if stage.rawValue >= LessonStage.implement.rawValue { pathPanel }
                content.frame(maxWidth: .infinity, alignment: .leading).font(Lab.soft(17))
                footer
            }
        }
        .padding(24)
        .frame(minWidth: 480, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity, alignment: .topLeading)
        .labPanel(corner: 32, tint: Brand.telemetry, variant: .tide, aurora: 0.25)
        .tint(Brand.telemetry)
        .animation(.spring(duration: 0.3), value: stage)
        .animation(.spring(duration: 0.3), value: line)
        .animation(.spring(duration: 0.3), value: picking)
        .animation(.spring(duration: 0.3), value: demos)
        .onAppear { reset() }
        .onChange(of: model.lesson?.id) { demos = false; reset() }
        .onChange(of: stage) { old, new in if new == .implement && old == .pseudocode && lesson.blockProgram == nil { openCode() } }
        .onChange(of: model.flight.phase) { _, p in
            if p == .finished, !demos, stage == .run, model.lastReport != nil { model.lessonStage = .analyze }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Button { picking.toggle() } label: {
                VStack(alignment: .leading, spacing: 6) {
                    LabCaption("Lesson \(String(format: "%02d", lesson.id)) · Learn \(picking ? "▴" : "▾")")
                    Text(lesson.title).font(Lab.display(24)).foregroundStyle(Brand.ink)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button { demos.toggle(); picking = false } label: { Label("Demos", systemImage: demos ? "play.square.fill" : "play.square") }
                .buttonStyle(LabSecondaryButtonStyle(tint: demos ? Brand.ignition : Brand.telemetry))
                .accessibilityLabel("Demo scenarios")
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
                    model.lessonStage = .concept
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
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .labCard(corner: 16, tint: l.id == lesson.id ? Brand.telemetry : Lab.edge, aurora: 0.06)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stagePicker: some View {
        LabStagePicker(titles: LessonStage.allCases.map(short), selection: Binding(
            get: { stage.rawValue },
            set: { if let s = LessonStage(rawValue: $0) { model.lessonStage = s } }))
    }

    /// The trajectory of the rocket: the simulator's forecast of the current code, the rocket at the cursor, and the real rocket live.
    private var pathPanel: some View {
        LiveFlightPath(course: lesson.mission.course, cursor: $pathCursor, height: 120)
            .padding(14)
            .labCard(corner: 22, tint: Brand.telemetry, aurora: 0.12)
    }

    private func short(_ s: LessonStage) -> String {
        switch s { case .concept: "Idea"; case .pseudocode: "Order"; case .implement: "Code"; case .run: "Fly"; case .analyze: "Debrief" }
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
            if i == 0 {
                Text("YOUR JOB · \(goalText)").font(Brand.label(11)).tracking(1.5).foregroundStyle(Brand.ignition)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
            MiniGameView(lesson: lesson.id)
        }
    }

    @ViewBuilder private var pseudocode: some View {
        if lesson.blockProgram != nil {
            implement
        } else {
            textPseudocode
        }
    }

    private var textPseudocode: some View {
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
            .padding(12)
            .labCard(corner: 16, tint: checkResult == false ? Brand.ignition : Brand.telemetry, aurora: 0.06)
            FlowBlocks(items: pool) { b in
                if let k = pool.firstIndex(of: b) { pool.remove(at: k) }
                placed.append(b); checkResult = nil
                if pool.count <= lesson.distractors.count { check() }
            }
            if checkResult == false {
                Text("Order is off. Tap a placed block to send it back.").font(Lab.soft(20)).foregroundStyle(Brand.ignition)
            }
        }
    }

    /// Guided build: one block per step, picked from the palette by tap, numbers tuned with − / +.
    @ViewBuilder private var implement: some View {
        if let p = lesson.blockProgram {
            let ws = model.workspace(for: lesson)
            let next = p.solution.first { !ws.order.contains($0) }
            let done = p.solution.count - (next == nil ? 0 : p.solution.filter { !ws.order.contains($0) }.count)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("STEP \(min(done + 1, p.solution.count)) OF \(p.solution.count)").font(Brand.label(11)).tracking(2).foregroundStyle(Brand.telemetry)
                    Spacer()
                    ForEach(p.solution.indices, id: \.self) { i in
                        Capsule().fill(i < done ? Brand.telemetry : Lab.faint.opacity(0.4)).frame(width: i == done ? 18 : 7, height: 7)
                    }
                }
                if let n = next.flatMap(p.spec) {
                    Text(n.summary).font(Lab.soft(18)).foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
                    Text("Tap the block that does this. Remove a wrong one with ×.").font(Lab.soft(13)).foregroundStyle(Lab.muted)
                } else {
                    Text("Program written. Tune the numbers with − and +, then take it to the pad.").font(Lab.soft(18)).foregroundStyle(Brand.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Goal: \(goalText)").font(Lab.soft(13)).foregroundStyle(Lab.muted)
                }
                BlockComposer(program: p, order: Binding(get: { ws.order }, set: { ws.order = $0; checkResult = nil; if $0 == p.solution { check() } }),
                              values: Binding(get: { ws.values }, set: { ws.values = $0 }),
                              errorBlockID: ws.errorBlock(line: model.codeProblem?.line))
                    .frame(height: 340)
                prediction
                if wrongTail(ws.order, p) {
                    Text("That block runs later or does not belong. Tap × to remove it.").font(Lab.soft(20)).foregroundStyle(Brand.ignition)
                }
                if let n = next {
                    Button("Show me", systemImage: "lightbulb") { hint(n, ws, p) }.buttonStyle(LabGhostButton())
                }
            }
            .onAppear { ws.publish() }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Write update(dt) in the code window. Each TODO is one line. The dotted path re-predicts on every edit.")
                Text("Goal: \(goalText)").font(Lab.soft(14)).foregroundStyle(Lab.muted)
                prediction
            }
        }
    }

    /// Placed blocks that are not a prefix of the solution: the player went off track.
    private func wrongTail(_ order: [String], _ p: BlockProgram) -> Bool {
        !order.isEmpty && !p.solution.starts(with: order)
    }

    /// Drop wrong blocks, then place the next correct one.
    private func hint(_ id: String, _ ws: CodeWorkspaceModel, _ p: BlockProgram) {
        var o = ws.order.filter { p.solution.contains($0) }
        o = p.solution.filter { o.contains($0) }
        o.append(id)
        ws.order = p.solution.filter { o.contains($0) }
    }

    private var run: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch model.flight.phase {
            case .flying: Text("In flight. Watch the craft on the pad ahead.")
            default: Text("Craft on the pad, code loaded. Launch when ready.")
            }
            prediction
            if !model.blockers.isEmpty {
                Text("Blocked: \(model.blockers.map(\.title).joined(separator: ", "))").font(Lab.soft(20)).foregroundStyle(Brand.ignition)
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
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .labCard(corner: 16, tint: picked ? Brand.telemetry : Lab.edge, aurora: 0.06)
                }
                .buttonStyle(.plain)
            }
            if let g = model.grade(lesson) {
                Text("SCORE \(g.score) · " + String(repeating: "★", count: g.stars) + String(repeating: "☆", count: 3 - g.stars))
                    .font(Lab.display(18)).foregroundStyle(Brand.ignition)
            } else if model.lastReport != nil {
                Text("Mission not passed. Fix the code and fly again.").font(Lab.soft(20)).foregroundStyle(Brand.ignition)
            }
        }
    }

    @ViewBuilder private var prediction: some View {
        if case let .error(e) = model.compileStatus {
            Text("Line \(e.line): \(e.message)").font(Lab.mono(20)).foregroundStyle(Lab.danger)
        } else if let p = model.preview {
            if let f = p.result.failure {
                Text("Predicted: \(f.title)").font(Lab.display(22)).foregroundStyle(Brand.ignition)
            } else {
                Text("Predicted: pass, apogee \(Int(p.result.apogee)) m").font(Lab.display(22)).foregroundStyle(Brand.telemetry)
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
        case .pseudocode: Button(lesson.blockProgram != nil ? "Clear" : "Shuffle") { if lesson.blockProgram != nil { model.workspace(for: lesson).order = []; checkResult = nil } else { reset() } }.buttonStyle(LabSecondaryButtonStyle())
        case .implement: Button("Open code") { openCode() }.buttonStyle(LabSecondaryButtonStyle())
        case .run where model.flight.phase == .flying: Button("Open code") { openCode() }.buttonStyle(LabSecondaryButtonStyle())
        case .analyze: Button("Fly again") { model.lessonStage = .run }.buttonStyle(LabSecondaryButtonStyle())
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
        case .pseudocode: checkResult != true && (lesson.blockProgram != nil ? model.workspace(for: lesson).order.isEmpty : placed.isEmpty)
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
                    model.select(lesson: n); model.lessonStage = .concept; model.openLesson = n
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
        if let p = lesson.blockProgram { checkResult = model.workspace(for: lesson).order == p.solution }
        else { checkResult = placed == lesson.blocks }
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
        dismissWindow(id: WindowID.lesson)
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

/// Fallback block chips for lessons without a block palette: tappable, in the shared card style.
struct FlowBlocks: View {
    let items: [String]
    let tap: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { b in
                Button { tap(b) } label: {
                    Text(b).font(Lab.mono(14)).foregroundStyle(Lab.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .labCard(corner: 14, tint: Brand.trajectory, aurora: 0.06)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
