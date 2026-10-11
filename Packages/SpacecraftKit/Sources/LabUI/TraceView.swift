import SwiftUI
import FlightRunner
import Curriculum

/// Steps through one recorded guidance tick: the line about to run, the variables then (with what just changed),
/// and the craft calls the line made. Loop lines show how many times they ran.
public struct TraceView: View {
    public var report: TraceReport
    public var source: String
    public var origins: [LineOrigin?]
    @Binding public var step: Int
    /// Reports the block line behind the current step so a neighbouring `BlockComposer` can light it.
    public var onLit: (LineOrigin?) -> Void
    @State private var playing = false

    public init(report: TraceReport, source: String, origins: [LineOrigin?] = [], step: Binding<Int>, onLit: @escaping (LineOrigin?) -> Void = { _ in }) {
        self.report = report; self.source = source; self.origins = origins; _step = step; self.onLit = onLit
    }

    private var current: TraceStep? { report.steps.indices.contains(step) ? report.steps[step] : nil }
    private var previous: TraceStep? { report.steps.indices.contains(step - 1) ? report.steps[step - 1] : nil }
    private var visits: [Int: Int] { report.steps.reduce(into: [:]) { $0[$1.line, default: 0] += 1 } }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let err = report.compileError {
                Text(err).font(Lab.mono(13)).foregroundStyle(Color(red: 1, green: 0.83, blue: 0.85)).padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.24, green: 0.04, blue: 0.11).opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            } else if report.steps.isEmpty {
                Text("No guidance tick to trace yet.").font(Lab.soft(13)).foregroundStyle(Lab.muted)
            } else {
                chips
                controls
                CodeSurface(source: source, currentLine: current?.line, visits: visits, errorLine: step == report.steps.count - 1 ? report.faultLine : nil,
                            errorText: step == report.steps.count - 1 ? report.fault : nil)
                    .frame(minHeight: 140)
                variables
            }
        }
        .onChange(of: step) { _, _ in publishLit() }
        .onAppear { publishLit() }
        .task(id: playing) {
            guard playing else { return }
            while playing, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(260))
                if step >= report.steps.count - 1 { playing = false } else { step += 1 }
            }
        }
    }

    private func publishLit() {
        guard let line = current?.line, origins.indices.contains(line - 1) else { onLit(nil); return }
        onLit(origins[line - 1])
    }

    private var chips: some View {
        HStack(spacing: 6) {
            chip("compiled", "\(report.bytecodeOps) ops", good: true)
            chip("tick", String(format: "%.2f s", report.time))
            chip("steps", "\(report.steps.count)")
            chip("budget", "\(report.instructions) / \(report.instructionBudget.formatted())")
        }
    }

    private func chip(_ k: String, _ v: String, good: Bool = false) -> some View {
        HStack(spacing: 4) { Text(k).foregroundStyle(Lab.muted); Text(v).foregroundStyle(good ? Lab.teal : Lab.ink).fontWeight(.semibold) }
            .font(Lab.mono(11.5)).padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(Color(red: 0.05, green: 0.06, blue: 0.21).opacity(0.94)))
            .overlay { Capsule().stroke(good ? Lab.teal.opacity(0.5) : Lab.edge.opacity(0.3), lineWidth: 1) }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button { playing = false; step = max(0, step - 1) } label: { Image(systemName: "backward.fill") }.buttonStyle(LabIconButton())
            Button { if step >= report.steps.count - 1 { step = 0 }; playing.toggle() } label: { Text(playing ? "PAUSE" : "PLAY") }.buttonStyle(LabPrimaryButton())
            Button { playing = false; step = min(report.steps.count - 1, step + 1) } label: { Image(systemName: "forward.fill") }.buttonStyle(LabIconButton())
            Slider(value: Binding(get: { Double(step) }, set: { playing = false; step = Int($0.rounded()) }), in: 0...Double(max(1, report.steps.count - 1)), step: 1)
                .tint(Lab.teal)
        }
    }

    private var variables: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(current.map { "VARIABLES BEFORE LINE \($0.line) RUNS" } ?? "VARIABLES").font(Lab.label(10)).tracking(1.4).foregroundStyle(Lab.muted)
            let prevByName = Dictionary(uniqueKeysWithValues: (previous?.variables ?? []).map { ($0.name, $0.text) })
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(current?.variables ?? [], id: \.name) { v in
                    let changed = prevByName[v.name] != v.text
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 8) {
                            Text(v.name).foregroundStyle(Lab.Syntax.variable)
                            Text(Self.format(v)).foregroundStyle(Lab.Syntax.number).fontWeight(.semibold)
                        }
                        if changed, let was = prevByName[v.name] { Text("was \(was)").font(Lab.mono(10.5)).foregroundStyle(Lab.faint) }
                    }
                    .font(Lab.mono(12)).padding(.horizontal, 9).padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 9).fill(changed ? Lab.teal.opacity(0.18) : Lab.edge.opacity(0.07)))
                    .overlay { if changed { RoundedRectangle(cornerRadius: 9).stroke(Lab.teal.opacity(0.5), lineWidth: 1) } }
                }
            }
            if let calls = current?.calls, !calls.isEmpty {
                ForEach(Array(calls.enumerated()), id: \.offset) { _, c in
                    Text(PythonSyntax.attributed(c, size: 12)).font(Lab.mono(12)).padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Capsule().fill(Lab.violet.opacity(0.18)))
                }
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.02, green: 0.025, blue: 0.12).opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Angles read better in degrees; everything else is trimmed to what matters.
    static func format(_ v: TraceVar) -> String {
        guard let n = v.number, !v.text.hasPrefix("'") else { return v.text }
        let lower = v.name.lowercased()
        let isAngle = ["angle", "bearing", "pitch", "yaw", "roll", "heading", "err"].contains { lower.contains($0) } && abs(n) <= 2 * .pi + 0.01 && lower != "errors"
        let s = n == n.rounded() ? String(Int(n)) : String(format: "%.3g", n)
        return isAngle && n != 0 ? "\(s)  (\(String(format: "%.0f", n * 180 / .pi))°)" : s
    }
}

// MARK: - Buttons

public struct LabPrimaryButton: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Lab.label(11)).tracking(1.2).foregroundStyle(Color(red: 0.02, green: 0.07, blue: 0.16))
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(Capsule().fill(LinearGradient(colors: [Lab.teal, Color(red: 0.5, green: 0.71, blue: 1)], startPoint: .leading, endPoint: .trailing)))
            .shadow(color: Lab.teal.opacity(0.4), radius: 12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

public struct LabIconButton: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12)).foregroundStyle(Lab.ink).frame(width: 34, height: 30)
            .background(Capsule().fill(Lab.edge.opacity(configuration.isPressed ? 0.3 : 0.14)))
            .overlay { Capsule().stroke(Lab.edge.opacity(0.3), lineWidth: 1) }
    }
}
