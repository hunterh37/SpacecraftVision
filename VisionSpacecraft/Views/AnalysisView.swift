import SwiftUI
import Charts
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
                if let r = model.lastReport {
                    ResultCard(report: r)
                    FlightPlots(report: r, ghosts: Array(model.reports.dropLast().suffix(2)), compact: compact)
                    if !r.events.isEmpty && !compact {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Events").font(.headline)
                            ForEach(r.events, id: \.self) { Text($0).font(.caption.monospaced()) }
                        }
                    }
                } else {
                    ContentUnavailableView("No flights yet", systemImage: "chart.xyaxis.line",
                                           description: Text("Launch a flight in the range. Plots appear here when it ends."))
                }
            }
            .padding(20)
        }
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
            Text(title).font(.subheadline.bold())
            Chart(pts) { p in
                LineMark(x: .value("t (s)", p.t), y: .value(title, p.v))
                    .foregroundStyle(by: .value("Run", p.run))
                    .lineStyle(StrokeStyle(lineWidth: p.run == "This run" ? 2 : 1))
            }
            .chartXAxisLabel("t (s)")
            .chartForegroundStyleScale(["This run": Color.blue, "Run -1": Color.gray, "Run -2": Color.gray.opacity(0.5)])
            .frame(height: compact ? 150 : 200)
            .padding(10)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
            .environment(\.colorScheme, .light)
        }
    }
}
