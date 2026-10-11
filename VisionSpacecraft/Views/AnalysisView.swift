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
            VStack(alignment: .leading, spacing: 16) {
                LabHeader(kicker: "\(model.mission.id) · Analysis", title: "Flight data", tint: Brand.trajectory)
                if let r = model.lastReport {
                    ResultCard(report: r)
                    FlightPlots(report: r, ghosts: Array(model.reports.dropLast().suffix(2)), compact: compact)
                    if !r.events.isEmpty && !compact {
                        VStack(alignment: .leading, spacing: 2) {
                            LabCaption("Events", tint: Brand.ignition).padding(.bottom, 6)
                            ForEach(r.events, id: \.self) { Text($0).font(Lab.mono(12)).foregroundStyle(Lab.muted) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .labCard()
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.xyaxis.line").font(.system(size: 40, weight: .bold)).foregroundStyle(Brand.trajectory)
                        Text("NO FLIGHTS YET").font(Lab.display(20))
                        Text("Launch a flight in the range. Plots appear here when it ends.").font(Lab.soft(14)).foregroundStyle(Lab.muted)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 60)
                }
            }
            .padding(28)
        }
        .labWindow(tint: Brand.trajectory, variant: .dusk, aurora: 0.18)
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
        VStack(alignment: .leading, spacing: 4) {
            LabCaption(title, tint: Brand.telemetry)
            Chart(pts) { p in
                LineMark(x: .value("t (s)", p.t), y: .value(title, p.v))
                    .foregroundStyle(by: .value("Run", p.run))
                    .lineStyle(StrokeStyle(lineWidth: p.run == "This run" ? 2 : 1))
            }
            .chartXAxisLabel("t (s)")
            .chartForegroundStyleScale(["This run": Brand.telemetry, "Run -1": Brand.trajectory.opacity(0.7), "Run -2": Lab.faint])
            .chartXAxis { AxisMarks { AxisGridLine().foregroundStyle(Lab.edge.opacity(0.15)); AxisValueLabel().font(Lab.mono(10)).foregroundStyle(Lab.muted) } }
            .chartYAxis { AxisMarks { AxisGridLine().foregroundStyle(Lab.edge.opacity(0.15)); AxisValueLabel().font(Lab.mono(10)).foregroundStyle(Lab.muted) } }
            .frame(height: compact ? 150 : 200)
            .labCard(corner: 16, padding: 12)
            .environment(\.colorScheme, .dark)
        }
    }
}
