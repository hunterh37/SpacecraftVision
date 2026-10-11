import SwiftUI
import SpacecraftCore
import FlightSim

/// Telemetry and flight controls (specs/03, labels from specs/16 `btn.*`), plus the pass/fail card.
struct FlightHUDView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model
        let f = model.flight
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(model.mission.id) \(model.mission.title)").font(.title3.bold())
                Spacer()
                Picker("View", selection: $model.flightView) {
                    ForEach(FlightView.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    stat("Altitude", "\(Int(f.altitude)) m"); stat("Speed", "\(Int(f.speed)) m/s")
                    stat("Throttle", "\(Int(f.throttle * 100))%"); stat("Time", String(format: "%.1f s", f.time))
                }
                GridRow {
                    stat("Fuel", "\(Int(f.fuel * 100))%"); stat("Energy", "\(Int(f.energy * 100))%")
                    if !model.mission.course.gates.isEmpty { stat("Gates", "\(f.gates) / \(model.mission.course.gates.count)") } else { stat("Chute", ["Packed", "Drogue", "Main", "Torn"][f.chuteStage]) }
                    stat("State", f.logLine.isEmpty ? "-" : f.logLine)
                }
            }
            .font(.body.monospacedDigit())
            if let fault = f.lastFault { Text(fault).font(.caption).foregroundStyle(.red) }
            HStack {
                switch f.phase {
                case .idle, .finished:
                    Button("Launch", systemImage: "flame.fill") { model.launch() }.buttonStyle(.borderedProminent)
                    if f.phase == .finished { Button("Reset") { f.reset() } }
                case .flying, .paused:
                    Button("Abort", systemImage: "xmark.octagon") { f.abort() }.tint(.red)
                    Button(f.phase == .paused ? "Resume" : "Pause") { f.togglePause() }
                    ForEach([0.25, 1.0, 4.0], id: \.self) { s in
                        Button(s == 0.25 ? "0.25x" : s == 1 ? "1x" : "4x") { f.timeScale = s }
                            .buttonStyle(.bordered).tint(f.timeScale == s ? .accentColor : .gray)
                    }
                }
                Spacer()
                Button("Code", systemImage: "chevron.left.forwardslash.chevron.right") { openWindow(id: WindowID.code) }
                Button("Analysis", systemImage: "chart.xyaxis.line") { openWindow(id: WindowID.analysis) }
            }
            if let err = f.launchError { Text(err).foregroundStyle(.red).font(.callout) }
            if let r = model.lastReport, f.phase == .finished { ResultCard(report: r) }
        }
        .padding(22)
        .frame(width: 700)
        .glassBackgroundEffect()
    }

    func stat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(k).font(.caption).foregroundStyle(.secondary)
            Text(v).lineLimit(1)
        }
    }
}

struct ResultCard: View {
    let report: FlightReport

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let f = report.result.failure {
                Label(f.title, systemImage: "xmark.circle.fill").font(.headline).foregroundStyle(.red)
                Text(f.body).font(.callout)
                Text(String(format: "At %.1f s", f.time)).font(.caption).foregroundStyle(.secondary)
            } else {
                Label("Mission passed", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(.green)
                Text("Score \(report.result.score). Apogee \(Int(report.result.apogee)) m, fuel used \(Int(report.result.fuelUsed)) kg.")
                    .font(.callout)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

import FlightRunner
