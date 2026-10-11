import SwiftUI
import LabUI
import Curriculum
import FlightRunner

/// A ready-made program for the current lesson: what it loads and what the flight should show.
struct LessonDemo: Identifiable, Hashable {
    let id: String
    let title: String
    let watch: String
    let order: [String]?
    let values: [String: Double]?
    let source: String?

    /// Built from the lesson's block palette: the solution, the starting numbers, each missing block, the decoy block.
    static func all(for lesson: Lesson) -> [LessonDemo] { crashes + programs(for: lesson) }

    /// Scripts that end in a destroyed craft, so the range plays the real explosion, debris and smoke.
    static let crashes: [LessonDemo] = [
        crash("hop", "Crash · short hop, no chute",
              "Engine cuts at 60 m and no chute opens. The craft drops back onto the pad and explodes.", """
              if craft.altitude() >= 60.0:
                  craft.set_throttle(0.0)
              """),
        crash("nochute", "Crash · high fall, no chute",
              "Engine cuts at 150 m, the craft coasts up, then falls the whole way and hits the ground.", """
              if craft.altitude() >= 150.0:
                  craft.set_throttle(0.0)
              """),
        crash("tip", "Crash · tips over",
              "Engine cuts at 15 m while the nose pitches hard. The rocket tumbles into the terrain.", """
              if craft.altitude() > 15.0:
                  craft.set_throttle(0.0)
                  craft.set_pitch(-8.0)
              """),
        crash("late", "Crash · chute too late",
              "Both chutes fire 8 m above the ground, too late to slow the fall.", """
              if craft.altitude() >= 150.0:
                  craft.set_throttle(0.0)
              if craft.velocity()[2] < 0.0 and craft.altitude() < 8.0 and not state["chute"]:
                  craft.stage()
                  craft.stage()
                  state["chute"] = True
              """),
    ]

    private static func crash(_ id: String, _ title: String, _ watch: String, _ update: String) -> LessonDemo {
        LessonDemo(id: "crash-\(id)", title: title, watch: watch, order: nil, values: nil, source: script(update: update))
    }

    private static func script(update raw: String) -> String {
        let body = raw.split(separator: "\n", omittingEmptySubsequences: false).map { "    " + $0 }.joined(separator: "\n")
        return """
        import craft

        state = {"chute": False}

        def setup():
            craft.set_throttle(1.0)

        def update(dt):
        \(body)
            craft.plot("altitude", craft.altitude())
        """
    }

    static func programs(for lesson: Lesson) -> [LessonDemo] {
        guard let p = lesson.blockProgram else {
            return [
                LessonDemo(id: "ref", title: "Working program", watch: "The reference solution. The mission passes.",
                           order: nil, values: nil, source: lesson.referenceCode),
                LessonDemo(id: "starter", title: "Empty starter", watch: "The TODOs are blank, so nothing steers the craft.",
                           order: nil, values: nil, source: lesson.starterCode),
            ]
        }
        var out = [
            LessonDemo(id: "ref", title: "Working program", watch: "All blocks in order, tuned numbers. The mission passes.",
                       order: p.solution, values: p.referenceValues, source: nil),
            LessonDemo(id: "start", title: "Right blocks, untuned numbers",
                       watch: "Same blocks with the starting numbers: " + p.knobs.map { "\($0.label) \(BlockProgram.pythonNumber($0.value))" }.joined(separator: ", ") + ".",
                       order: p.solution, values: p.startingValues, source: nil),
        ]
        for id in p.solution {
            guard let s = p.spec(id) else { continue }
            out.append(LessonDemo(id: "miss-\(id)", title: "Without “\(s.name)”", watch: "This step never runs: \(s.summary.lowercasedFirst)",
                                  order: p.solution.filter { $0 != id }, values: p.referenceValues, source: nil))
        }
        for s in p.specs where s.isDistractor {
            out.append(LessonDemo(id: "decoy-\(s.id)", title: "With the decoy “\(s.name)”", watch: "Added on top of the working program. \(s.summary)",
                                  order: p.solution + [s.id], values: p.referenceValues, source: nil))
        }
        out.append(LessonDemo(id: "empty", title: "No blocks", watch: "update(dt) does nothing. The craft flies on its defaults.",
                              order: [], values: p.referenceValues, source: nil))
        return out
    }
}

private extension String {
    var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }
}

/// Demos tab of the Learn deck: tap a scenario, it loads into the code and flies on the pad, then the player's own code comes back.
struct LessonDemoPanel: View {
    let lesson: Lesson
    let close: () -> Void
    @Environment(AppModel.self) private var model
    @State private var active: LessonDemo?
    @State private var saved: (order: [String], values: [String: Double], source: String, hand: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tap a scenario. It loads into the code and launches on the pad. Your own code comes back when you leave.")
                .font(Lab.soft(14)).foregroundStyle(Lab.muted).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(LessonDemo.all(for: lesson)) { d in row(d) }
                }
            }
            .frame(maxHeight: .infinity)
            if active != nil { status }
            HStack {
                Spacer()
                Button("Back to my code") { restore(); close() }.buttonStyle(BrandButtonStyle())
            }
        }
        .onDisappear { restore() }
    }

    private func row(_ d: LessonDemo) -> some View {
        let on = active?.id == d.id
        return Button { play(d) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: on ? "play.circle.fill" : "play.circle").font(.system(size: 22))
                    .foregroundStyle(on ? Brand.ignition : Brand.telemetry)
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.title).font(Lab.soft(17)).foregroundStyle(Lab.ink)
                    Text(d.watch).font(Lab.soft(13)).foregroundStyle(Lab.muted).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .labCard(corner: 16, tint: on ? Brand.ignition : Lab.edge, aurora: 0.06)
        }
        .buttonStyle(.plain)
        .disabled(model.flight.phase == .flying)
    }

    /// Forecast before launch, live altitude and speed in flight, the outcome after.
    @ViewBuilder private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch model.flight.phase {
            case .flying, .paused:
                Text("IN FLIGHT · \(Int(model.flight.altitude)) m · \(Int(model.flight.speed)) m/s")
                    .font(Brand.label(12)).tracking(1.5).foregroundStyle(Brand.telemetry)
            case .finished:
                if let r = model.lastReport {
                    if let f = r.result.failure {
                        Text("RESULT · \(f.title)").font(Brand.label(12)).tracking(1.5).foregroundStyle(Brand.ignition)
                        Text(f.body).font(Lab.soft(13)).foregroundStyle(Lab.muted).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("RESULT · passed, apogee \(Int(r.result.apogee)) m").font(Brand.label(12)).tracking(1.5).foregroundStyle(Brand.telemetry)
                    }
                }
            case .idle:
                Text("LOADING…").font(Brand.label(12)).tracking(1.5).foregroundStyle(Lab.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .labCard(corner: 14, tint: Brand.telemetry, aurora: 0.08)
    }

    private func play(_ d: LessonDemo) {
        let ws = model.workspace(for: lesson)
        if saved == nil { saved = (ws.order, ws.values, model.source, !ws.usesBlocks) }
        active = d
        if let o = d.order, let v = d.values {
            ws.backToBlocks()
            ws.order = o
            ws.values = v
            ws.publish()
        } else if let s = d.source {
            model.source = s
        }
        model.flightView = .ground
        model.launch()
    }

    private func restore() {
        guard let s = saved else { return }
        saved = nil
        active = nil
        let ws = model.workspace(for: lesson)
        if lesson.blockProgram != nil, !s.hand {
            ws.backToBlocks()
            ws.order = s.order
            ws.values = s.values
            ws.publish()
        } else if lesson.blockProgram != nil {
            ws.edit(source: s.source)
        } else {
            model.source = s.source
        }
    }
}
