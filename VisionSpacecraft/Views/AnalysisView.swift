import SwiftUI
import Charts
import LabUI
import FlightRunner
import FlightSim
import SpacecraftCore

/// Analysis window (specs/08): run list with compare (up to 4 overlaid), default figures in MATLAB colours,
/// failure report, replay in the range, and CSV / .m / source export.
struct AnalysisView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    var compact = false

    var selected: [FlightRecord] {
        let chosen = model.records.filter { model.compareIds.contains($0.id) }
        if !chosen.isEmpty { return chosen }
        return model.records.last.map { [$0] } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !compact { LabHeader("Analysis", caption: "Runs, figures and export", tint: Brand.ignition) }
                if model.records.isEmpty, let r = model.lastReport {
                    ResultCard(report: r)
                    FlightPlots(report: r, ghosts: Array(model.reports.dropLast().suffix(2)), compact: compact)
                } else if model.records.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line").font(.system(size: 34)).foregroundStyle(Brand.ignition)
                        Text("No flights yet").font(Brand.display(20)).foregroundStyle(Brand.ink)
                        Text("Launch a flight in the range. Plots appear here when it ends.").font(.system(size: 14, weight: .medium)).foregroundStyle(Brand.dim)
                    }
                    .padding(32).frame(maxWidth: .infinity).labCard(corner: 26, tint: Brand.ignition, variant: .ember, aurora: 0.2)
                } else {
                    RunList()
                    if let primary = selected.last {
                        ResultCard(report: primary.report)
                        ReplayBar(record: primary)
                        if primary.result.failure != nil { FailureReport(record: primary) }
                        if selected.count >= 2 { DiffSummary(runs: selected) }
                        RunFigures(runs: selected)
                        ExportRow(record: primary)
                    }
                }
            }
            .padding(compact ? 0 : 24)
        }
        .labWindow(tint: Brand.ignition, variant: .ember)
        .onAppear { model.analysisOpened = true }
    }
}

/// MATLAB default line colour order.
enum MatlabColors {
    static let order: [Color] = [Color(red: 0, green: 0.447, blue: 0.741), Color(red: 0.85, green: 0.325, blue: 0.098),
                                 Color(red: 0.929, green: 0.694, blue: 0.125), Color(red: 0.494, green: 0.184, blue: 0.556),
                                 Color(red: 0.466, green: 0.674, blue: 0.188)]
}

struct RunList: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RUNS  (select up to 4 to compare)").font(Brand.label(11)).tracking(2.2).foregroundStyle(Brand.dim)
            ForEach(model.records.suffix(12).reversed()) { r in
                let on = model.compareIds.contains(r.id)
                Button {
                    if on { model.compareIds.removeAll { $0 == r.id } }
                    else { model.compareIds.append(r.id); if model.compareIds.count > 4 { model.compareIds.removeFirst() } }
                } label: {
                    HStack {
                        Image(systemName: on ? "checkmark.square.fill" : "square")
                        Text(r.name).font(Brand.label(13))
                        Spacer()
                        Text(r.result.passed ? "pass  \(r.result.score)" : (r.result.failure?.title ?? "fail"))
                            .font(Brand.label(12)).foregroundStyle(r.result.passed ? Brand.telemetry : Brand.ignition)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).labCard(corner: 22, tint: Brand.trajectory, aurora: 0.08)
    }
}

struct FailureReport: View {
    let record: FlightRecord
    var body: some View {
        let f = record.result.failure!
        VStack(alignment: .leading, spacing: 6) {
            Text("FAILURE REPORT").font(Brand.label(11)).tracking(2.2).foregroundStyle(Brand.ignition)
            Text(f.title).font(Brand.display(18)).foregroundStyle(Brand.ink)
            Text(f.body).font(.system(size: 13)).foregroundStyle(Brand.dim)
            Text(String(format: "t %.2f s · tick %d · value %.2f vs limit %.2f", f.time, f.tick, f.value, f.limit)
                 + (f.part.map { " · part \($0)" } ?? "") + (f.line.map { " · line \($0)" } ?? ""))
                .font(Brand.label(12)).foregroundStyle(Brand.ink)
            let w = record.failureWindow
            if !w.isEmpty {
                Chart(w.indices, id: \.self) { i in
                    LineMark(x: .value("t (s)", w[i].t), y: .value("Altitude (m)", w[i].position.z)).foregroundStyle(MatlabColors.order[0])
                    LineMark(x: .value("t (s)", w[i].t), y: .value("Speed (m/s)", w[i].speed)).foregroundStyle(MatlabColors.order[1])
                }
                .frame(height: 120)
                Text("Last 3 s: altitude (blue), speed (orange)").font(Brand.label(11)).foregroundStyle(Brand.dim)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).labCard(corner: 22, tint: Brand.ignition, aurora: 0.1)
    }
}

struct DiffSummary: View {
    let runs: [FlightRecord]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CODE CHANGES").font(Brand.label(11)).tracking(2.2).foregroundStyle(Brand.dim)
            ForEach(Array(runs.dropFirst().enumerated()), id: \.offset) { i, r in
                Text("\(runs[i].name) → \(r.name): \(FlightRecord.linesChanged(runs[i].source, r.source)) lines changed")
                    .font(Brand.label(12)).foregroundStyle(Brand.ink)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).labCard(corner: 22, tint: Brand.trajectory, aurora: 0.05)
    }
}

struct ReplayBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    let record: FlightRecord
    var body: some View {
        @Bindable var f = model.flight
        HStack(spacing: 12) {
            if f.replay == nil || f.replayName != record.name {
                Button("Replay in range", systemImage: "play.circle") {
                    if let m = record.mission { model.mission = m }
                    f.startReplay(record)
                    if model.openSpace != .range { Task { _ = await openImmersiveSpace(id: SpaceID.range.rawValue) } }
                }
            } else {
                Button(f.replayPlaying ? "Pause" : "Play", systemImage: f.replayPlaying ? "pause.fill" : "play.fill") {
                    if f.replayTime >= f.replayDuration { f.seekReplay(0) }
                    f.replayPlaying.toggle()
                }
                Slider(value: Binding(get: { f.replayTime }, set: { f.seekReplay($0) }), in: 0...max(f.replayDuration, 0.1))
                Text(String(format: "%.1f s", f.replayTime)).font(Brand.label(12)).monospacedDigit()
                Picker("Speed", selection: $f.replaySpeed) {
                    ForEach([0.25, 1, 4, 10], id: \.self) { Text("\($0, specifier: "%g")x").tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 200)
                Button("Stop", systemImage: "stop.fill") { f.stopReplay() }
            }
        }
        .padding(14).labCard(corner: 20, tint: Brand.telemetry, aurora: 0.05)
    }
}

struct ExportRow: View {
    let record: FlightRecord
    var body: some View {
        let files = (try? FlightExport.write(record)) ?? []
        HStack {
            Text("EXPORT").font(Brand.label(11)).tracking(2.2).foregroundStyle(Brand.dim)
            Spacer()
            ForEach(files, id: \.self) { u in
                ShareLink(item: u) { Label(u.pathExtension.uppercased(), systemImage: "square.and.arrow.up") }
            }
            if !files.isEmpty {
                ShareLink(items: files) { Label("All", systemImage: "square.and.arrow.up.on.square") }
            }
        }
        .padding(14).labCard(corner: 20, tint: Brand.trajectory, aurora: 0.05)
    }
}

/// Default figures (specs/08) for one or more runs, overlaid with a legend.
struct RunFigures: View {
    let runs: [FlightRecord]
    struct Pt: Identifiable { let id: Int; let x: Double; let y: Double; let run: String }

    func series(_ f: (FlightSample) -> Double?) -> [Pt] {
        var out: [Pt] = []
        for (k, r) in runs.enumerated() {
            let s = r.samples, step = max(1, s.count / 400)
            for i in stride(from: 0, to: s.count, by: step) { if let v = f(s[i]) { out.append(Pt(id: k * 1_000_000 + i, x: s[i].t, y: v, run: r.name)) } }
        }
        return out
    }

    func path(_ f: (FlightSample) -> (Double, Double)) -> [Pt] {
        var out: [Pt] = []
        for (k, r) in runs.enumerated() {
            let s = r.samples, step = max(1, s.count / 400)
            for i in stride(from: 0, to: s.count, by: step) { let p = f(s[i]); out.append(Pt(id: k * 1_000_000 + i, x: p.0, y: p.1, run: r.name)) }
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            figure("Altitude", "t (s)", "altitude (m)", series { $0.position.z })
            figure("Speed", "t (s)", "speed (m/s)", series { $0.speed })
            figure("Throttle", "t (s)", "throttle", series { $0.throttle })
            figure("Fuel", "t (s)", "fuel (0..1)", series { $0.fuel })
            figure("Energy", "t (s)", "energy (Wh)", series { $0.energy })
            figure("Max part temperature", "t (s)", "temperature (K)", series { $0.maxTemp > 0 ? $0.maxTemp : nil })
            figure("Closest obstacle", "t (s)", "clearance (m)", series { $0.clearance })
            figure("Top-down path", "x east (m)", "y north (m)", path { ($0.position.x, $0.position.y) }, ordered: true)
            figure("Side profile", "downrange (m)", "altitude (m)", path { ((($0.position.x * $0.position.x) + ($0.position.y * $0.position.y)).squareRoot(), $0.position.z) }, ordered: true)
            ForEach(Set(runs.flatMap { $0.series.keys }).sorted(), id: \.self) { name in
                figure(name, "t (s)", name, runs.enumerated().flatMap { k, r in
                    let v = r.series[name] ?? [], t = r.seriesTime[name] ?? []
                    let step = max(1, v.count / 400)
                    return stride(from: 0, to: min(v.count, t.count), by: step).map { Pt(id: k * 1_000_000 + $0, x: t[$0], y: v[$0], run: r.name) }
                })
            }
        }
    }

    func figure(_ title: String, _ xl: String, _ yl: String, _ pts: [Pt], ordered: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.black)
            if pts.isEmpty {
                Text("No data for this run").font(.system(size: 12)).foregroundStyle(.gray).frame(height: 60)
            } else {
                Chart(pts) { p in
                    LineMark(x: .value(xl, p.x), y: .value(yl, p.y), series: .value("Run", p.run))
                        .foregroundStyle(by: .value("Run", p.run))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartForegroundStyleScale(domain: runs.map(\.name), range: Array(MatlabColors.order.prefix(max(1, runs.count))))
                .chartXAxisLabel(xl).chartYAxisLabel(yl)
                .chartXAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(.gray.opacity(0.35)); AxisTick(); AxisValueLabel().foregroundStyle(.black) } }
                .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(.gray.opacity(0.35)); AxisTick(); AxisValueLabel().foregroundStyle(.black) } }
                .chartLegend(runs.count > 1 ? .visible : .hidden)
                .frame(height: 170)
            }
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 10))
        .environment(\.colorScheme, .light)
    }
}

struct FlightPlots: View {
    let report: FlightReport
    var ghosts: [FlightReport] = []
    var compact = false

    struct Pt: Identifiable { let id: Int; let t: Double; let v: Double; let run: String }

    func points(_ r: FlightReport, run: String, _ f: (FlightSample) -> Double) -> [Pt] {
        let s = r.samples
        let stride = max(1, s.count / 400)
        return Swift.stride(from: 0, to: s.count, by: stride).map { Pt(id: $0, t: s[$0].t, v: f(s[$0]), run: run) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            plot("Altitude (m)") { r, run in points(r, run: run) { $0.position.z } }
            plot("Vertical velocity (m/s)") { r, run in points(r, run: run) { $0.velocity.z } }
            if !compact {
                ForEach(report.series.keys.sorted(), id: \.self) { name in
                    let v = report.series[name] ?? [], t = report.seriesTime[name] ?? []
                    let stride = max(1, v.count / 400)
                    let pts = Swift.stride(from: 0, to: min(v.count, t.count), by: stride).map { Pt(id: $0, t: t[$0], v: v[$0], run: "This run") }
                    chart(name, pts)
                }
            }
        }
    }

    func plot(_ title: String, _ f: (FlightReport, String) -> [Pt]) -> some View {
        var pts = f(report, "This run")
        for (i, g) in ghosts.enumerated() { pts += f(g, "Run -\(ghosts.count - i)").map { Pt(id: $0.id + 100_000 * (i + 1), t: $0.t, v: $0.v, run: $0.run) } }
        return chart(title, pts)
    }

    func chart(_ title: String, _ pts: [Pt]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(Brand.label(11)).tracking(2).foregroundStyle(Brand.telemetry)
            Chart(pts) { p in
                LineMark(x: .value("t (s)", p.t), y: .value(title, p.v))
                    .foregroundStyle(by: .value("Run", p.run))
                    .lineStyle(StrokeStyle(lineWidth: p.run == "This run" ? 2.5 : 1.2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            .chartXAxisLabel("t (s)", alignment: .trailing)
            .chartXAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisTick().foregroundStyle(.white.opacity(0.25)); AxisValueLabel().foregroundStyle(Brand.dim) } }
            .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisValueLabel().foregroundStyle(Brand.dim) } }
            .chartForegroundStyleScale(["This run": Brand.telemetry, "Run -1": Brand.trajectory.opacity(0.7), "Run -2": Brand.ignition.opacity(0.55)])
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: compact ? 140 : 190)
            .padding(14)
            .labPlate()
            .environment(\.colorScheme, .dark)
        }
    }
}
