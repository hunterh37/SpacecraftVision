import SwiftUI
import SpacecraftCore
import FlightRunner
import Curriculum

/// State behind the coding window: the block script (or hand-edited Python), the generated source, and the trace.
/// The host app supplies two things: where source changes go, and how to trace a tick.
@MainActor @Observable
public final class CodeWorkspaceModel {
    public enum Tab: String, CaseIterable, Identifiable, Sendable { case blocks = "Blocks", python = "Python", trace = "Trace"; public var id: String { rawValue } }

    public private(set) var lesson: Lesson
    public private(set) var program: BlockProgram?
    public var tab: Tab = .blocks
    public var order: [String] = [] { didSet { if order != oldValue { changed() } } }
    public var values: [String: Double] = [:] { didSet { if values != oldValue { changed() } } }
    /// Set once the player edits Python by hand; blocks stop driving the source until they ask for them back.
    public private(set) var handEdited: String?

    public var trace: TraceReport?
    public var traceStep = 0
    public var traceTime = 3.0
    public var tracing = false
    public var lit: LineOrigin?

    private let sink: @MainActor (String) -> Void
    private let tracer: @MainActor (String, Double) async -> TraceReport

    public init(lesson: Lesson, initialSource: String? = nil, sink: @escaping @MainActor (String) -> Void, tracer: @escaping @MainActor (String, Double) async -> TraceReport) {
        self.lesson = lesson; program = lesson.blockProgram; self.sink = sink; self.tracer = tracer
        values = program?.startingValues ?? [:]
        if program == nil { tab = .python; handEdited = initialSource ?? lesson.starterCode }
    }

    public var composed: ComposedSource? { program.map { $0.compose(order: order, values: values) } }
    public var source: String { handEdited ?? composed?.source ?? lesson.starterCode }
    public var usesBlocks: Bool { program != nil && handEdited == nil }

    /// Push the current source to the host (call once after creating the model so the preview matches the blocks).
    public func publish() { sink(source) }

    private func changed() { guard handEdited == nil else { return }; sink(source); trace = nil }

    public func edit(source: String) { handEdited = source; sink(source); trace = nil }
    public func backToBlocks() { handEdited = nil; sink(source); trace = nil }
    public func resetToStarter() { order = []; values = program?.startingValues ?? [:]; handEdited = program == nil ? lesson.starterCode : nil; sink(source); trace = nil }
    public func loadSolution() { guard let p = program else { return }; order = p.solution; values = p.referenceValues; handEdited = nil; sink(source); trace = nil }

    /// Which block produced the failing source line, if any.
    public func errorBlock(line: Int?) -> String? {
        guard handEdited == nil, let line, let o = composed?.origins, o.indices.contains(line - 1) else { return nil }
        return o[line - 1]?.blockID
    }

    public func runTrace() async {
        tracing = true
        let src = source, t = traceTime
        let report = await tracer(src, t)
        trace = report; traceStep = 0; tracing = false
        lit = nil
    }
}

/// Tabs, blocks, Python and trace in one container. Errors come from the host (compile or preview).
public struct CodeWorkspace: View {
    @Bindable public var model: CodeWorkspaceModel
    public var errorLine: Int?
    public var errorText: String?
    /// Flight length in seconds, to bound the trace time slider.
    public var flightDuration: Double
    /// The simulator's own prediction of the current code, the course it flies, and (during a launch) the real rocket so far.
    public var report: FlightReport?
    public var course: Course?
    public var live: FlightLive?
    @State private var width: CGFloat = 0

    public init(model: CodeWorkspaceModel, errorLine: Int? = nil, errorText: String? = nil, flightDuration: Double = 60,
                report: FlightReport? = nil, course: Course? = nil, live: FlightLive? = nil) {
        self.model = model; self.errorLine = errorLine; self.errorText = errorText; self.flightDuration = flightDuration
        self.report = report; self.course = course; self.live = live
    }

    @ViewBuilder private func pathView(height: CGFloat) -> some View {
        if let course {
            FlightPathView(report: report, course: course, live: live, cursor: $model.traceTime, height: height,
                           onScrubEnd: { if model.tab == .trace { Task { await model.runTrace() } } })
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Group {
                switch model.tab {
                case .blocks: blocks
                case .python: python
                case .trace: traceTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(18)
        .labPanel(tint: errorText == nil ? Brand.telemetry : Lab.danger, variant: model.tab == .python ? .dusk : .tide)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
        .onChange(of: model.tab) { _, t in if t == .trace { Task { await model.runTrace() } } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(CodeWorkspaceModel.Tab.allCases.filter { $0 != .blocks || model.program != nil }) { t in
                    Button(t.rawValue) { model.tab = t }
                        .buttonStyle(.plain).font(Lab.soft(13)).foregroundStyle(model.tab == t ? Lab.ink : Lab.muted)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Capsule().fill(model.tab == t ? Lab.edge.opacity(0.25) : .clear))
                }
            }
            .padding(3).background(Capsule().fill(Color(red: 0.02, green: 0.03, blue: 0.14).opacity(0.7))).overlay { Capsule().stroke(Lab.edge.opacity(0.25), lineWidth: 1) }
            Spacer()
            statusDot
        }
    }

    /// Brand-style mono caption: a short tinted rule, then the state in tracked capitals.
    private var statusDot: some View {
        let tint = errorText == nil ? Brand.telemetry : Lab.danger
        return HStack(spacing: 8) {
            Rectangle().fill(tint).frame(width: 22, height: 3).clipShape(Capsule())
            Text(errorText == nil ? "COMPILES" : "ERROR IN YOUR CODE").font(Brand.label(11)).tracking(2).foregroundStyle(tint)
        }
    }

    private var errorBlockID: String? { model.errorBlock(line: errorLine) }

    @ViewBuilder private var blocks: some View {
        if model.usesBlocks, let p = model.program {
            VStack(spacing: 8) {
                BlockComposer(program: p, order: $model.order, values: $model.values, errorBlockID: errorBlockID)
                if let t = errorText {
                    HStack(spacing: 8) { Circle().fill(Lab.danger).frame(width: 8, height: 8); Text(t).font(Lab.mono(12)).foregroundStyle(Color(red: 1, green: 0.83, blue: 0.85)).lineLimit(2) }
                        .padding(.horizontal, 12).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.24, green: 0.04, blue: 0.11).opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                }
                pathView(height: 96)
                HStack {
                    Button("Load solution") { model.loadSolution() }.buttonStyle(.plain).font(Lab.soft(12)).foregroundStyle(Lab.muted)
                    Spacer()
                }
            }
        } else {
            VStack(spacing: 10) {
                Text("You are editing Python directly, so blocks are paused.").font(Lab.soft(14)).foregroundStyle(Lab.muted)
                if model.program != nil { Button("Back to blocks") { model.backToBlocks() }.buttonStyle(LabPrimaryButton()) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var python: some View {
        VStack(spacing: 8) {
            PythonEditor(text: Binding(get: { model.source }, set: { if $0 != model.source { model.edit(source: $0) } }), errorLine: errorLine, errorText: errorText)
            pathView(height: 90)
            if model.handEdited != nil, model.program != nil {
                HStack { Text("Hand-edited. Blocks are paused.").font(Lab.soft(12)).foregroundStyle(Lab.muted); Spacer(); Button("Back to blocks") { model.backToBlocks() }.buttonStyle(LabPrimaryButton()) }
            }
        }
    }

    private var traceTab: some View {
        VStack(spacing: 10) {
            if course != nil { pathView(height: 120) } else {
                HStack(spacing: 10) {
                    Text("TICK AT").font(Lab.label(10)).tracking(1.4).foregroundStyle(Lab.muted)
                    Slider(value: $model.traceTime, in: 0.1...max(1, flightDuration), step: 0.1) { editing in if !editing { Task { await model.runTrace() } } }.tint(Lab.violet)
                    Text(String(format: "%.1f s", model.traceTime)).font(Lab.mono(12)).foregroundStyle(Lab.ink).frame(width: 52, alignment: .trailing)
                }
            }
            if model.usesBlocks, let p = model.program, let c = model.composed, model.trace?.compileError == nil {
                let composer = BlockComposer(program: p, order: .constant(model.order), values: .constant(model.values), errorBlockID: nil, lit: model.lit, readOnly: true)
                let tv = model.trace.map { t in TraceView(report: t, source: c.source, origins: c.origins, step: $model.traceStep, onLit: { model.lit = $0 }) }
                if width > 980 {
                    HStack(alignment: .top, spacing: 14) { composer.frame(width: 360); tv }
                } else {
                    composer.frame(maxHeight: 220)
                    tv
                }
            } else if let t = model.trace {
                TraceView(report: t, source: model.source, step: $model.traceStep)
            } else {
                Text(model.tracing ? "Compiling and tracing..." : "Open this tab to trace one guidance tick.").font(Lab.soft(13)).foregroundStyle(Lab.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
