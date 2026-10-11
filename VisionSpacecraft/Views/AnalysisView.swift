import SwiftUI
import Charts
import LabUI
import FlightRunner
import FlightSim

/// MATLAB-style plots (specs/08): altitude and vertical velocity of the last run, previous runs as ghosts,
/// and any series the player's code wrote with `craft.plot`.
struct AnalysisView: View {
    @Environment(AppModel.self) private var model
    var compact = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !compact { LabHeader("Analysis", caption: "Last flight", tint: Brand.ignition) }
                if let r = model.lastReport {
                    ResultCard(report: r)
                    FlightPlots(report: r, ghosts: Array(model.reports.dropLast().suffix(2)), compact: compact)
                    if !r.events.isEmpty && !compact {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EVENTS").font(Brand.label(11)).tracking(2.2).foregroundStyle(Brand.dim)
                            ForEach(r.events, id: \.self) { Text($0).font(Brand.label(12)).foregroundStyle(Brand.ink) }
                        }
                        .padding(20).frame(maxWidth: .infinity, alignment: .leading).labCard(corner: 22, tint: Brand.trajectory, aurora: 0.1)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line").font(.system(size: 34)).foregroundStyle(Brand.ignition)
                        Text("No flights yet").font(Brand.display(20)).foregroundStyle(Brand.ink)
                        Text("Launch a flight in the range. Plots appear here when it ends.").font(.system(size: 14, weight: .medium)).foregroundStyle(Brand.dim)
                    }
                    .padding(32).frame(maxWidth: .infinity).labCard(corner: 26, tint: Brand.ignition, variant: .ember, aurora: 0.2)
                }
            }
            .padding(compact ? 0 : 24)
        }
        .labWindow(tint: Brand.ignition, variant: .ember)
        .onAppear { model.analysisOpened = true }
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
