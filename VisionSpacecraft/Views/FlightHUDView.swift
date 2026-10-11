import SwiftUI
import SpacecraftCore
import FlightSim

/// Telemetry and flight controls (specs/03, labels from specs/16 `btn.*`), plus the pass/fail card.
struct FlightHUDView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace

    var body: some View {
        @Bindable var model = model
        let f = model.flight
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.mission.id).font(Brand.label(14)).foregroundStyle(Brand.ignition).tracking(2)
                Text(model.mission.title.uppercased()).font(Brand.display(22)).foregroundStyle(Brand.ink)
                Spacer()
                Picker("View", selection: $model.flightView) {
                    ForEach(FlightView.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            if f.phase == .idle { preflight } else { telemetry(f) }
            if let fault = f.lastFault { Text(fault).font(Brand.label(12)).foregroundStyle(Brand.ignition) }
            HStack(spacing: 10) {
                switch f.phase {
                case .idle, .finished:
                    Button("Launch", systemImage: "flame.fill") { model.launch() }
                        .buttonStyle(BrandButtonStyle(tint: model.blockers.isEmpty ? Brand.ignition : Brand.dim))
                        .disabled(!model.blockers.isEmpty)
                    if f.phase == .finished { Button("Reset", systemImage: "arrow.counterclockwise") { f.reset() } }
                case .flying, .paused:
                    Button("Abort", systemImage: "xmark.octagon") { f.abort() }.tint(.red)
                    Button(f.phase == .paused ? "Resume" : "Pause") { f.togglePause() }
                    ForEach([0.25, 1.0, 4.0], id: \.self) { s in
                        Button(s == 0.25 ? "0.25x" : s == 1 ? "1x" : "4x") { f.timeScale = s }
                            .buttonStyle(.bordered).tint(f.timeScale == s ? Brand.telemetry : .gray)
                    }
                }
                Spacer()
                Button("Code", systemImage: "chevron.left.forwardslash.chevron.right") { openWindow(id: WindowID.code) }
                Button("Analysis", systemImage: "chart.xyaxis.line") { openWindow(id: WindowID.analysis) }
            }
            if let err = f.launchError { Text(err).foregroundStyle(Brand.ignition).font(.callout) }
            if let r = model.lastReport, f.phase == .finished { ResultCard(report: r) }
        }
        .padding(24)
        .frame(width: 700)
        .background(Brand.space.opacity(0.55), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .tint(Brand.ignition)
    }

    // MARK: Preflight (specs/07 hard constraints plus compile status)

    struct Check: Identifiable { let id: String; let label: String; let value: String; let ok: Bool }

    var checks: [Check] {
        let s = model.craft.stats(), m = model.mission
        let keys = Set(model.blockers.map(\.key))
        let compiled: Bool = { if case .error = model.compileStatus { return false }; return true }()
        return [
            Check(id: "command", label: "COMMAND", value: s.hasCommand ? "Probe core" : "None", ok: !keys.contains("fail.command")),
            Check(id: "mass", label: "MASS", value: "\(Int(s.wetMass.rounded())) / \(Int(m.massCap)) kg", ok: !keys.contains("fail.mass")),
            Check(id: "parts", label: "PARTS", value: "\(s.partCount) / \(m.partCap)", ok: !keys.contains("fail.part-list")),
            Check(id: "budget", label: "BUDGET", value: "\(s.cost) / \(m.budget) cr", ok: !keys.contains("fail.budget")),
            Check(id: "code", label: "CODE", value: compiled ? "Compiled" : "Error", ok: compiled),
        ]
    }

    var preflight: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(checks) { c in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: c.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(c.ok ? Brand.telemetry : Brand.ignition)
                            Text(c.label).font(Brand.label(10)).tracking(1.5).foregroundStyle(Brand.dim)
                        }
                        Text(c.value).font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(c.ok ? Brand.ink : Brand.ignition).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Brand.hull.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(c.ok ? Color.clear : Brand.ignition.opacity(0.7), lineWidth: 1))
                }
            }
            if let b = model.blockers.first {
                HStack(spacing: 10) {
                    Text(b.body).font(.callout).foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Load reference craft") { model.loadReferenceCraft() }.buttonStyle(BrandButtonStyle(tint: .white))
                    Button("Open hangar") {
                        Task { await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.workshop) }
                        openWindow(id: WindowID.parts)
                    }
                }
            } else if let p = model.preview {
                Text(p.result.failure.map { "Predicted: \($0.title). \($0.body)" }
                     ?? "Predicted: mission passed, apogee \(Int(p.result.apogee)) m.")
                    .font(.callout).foregroundStyle(p.result.failure == nil ? Brand.telemetry : Brand.ignition)
            }
        }
    }

    func telemetry(_ f: FlightController) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                stat("ALTITUDE", "\(Int(f.altitude)) m"); stat("SPEED", "\(Int(f.speed)) m/s")
                stat("THROTTLE", "\(Int(f.throttle * 100))%"); stat("TIME", String(format: "%.1f s", f.time))
            }
            GridRow {
                stat("FUEL", "\(Int(f.fuel * 100))%"); stat("ENERGY", "\(Int(f.energy * 100))%")
                if !model.mission.course.gates.isEmpty { stat("GATES", "\(f.gates) / \(model.mission.course.gates.count)") }
                else { stat("CHUTE", ["Packed", "Drogue", "Main", "Torn"][f.chuteStage]) }
                stat("STATE", f.logLine.isEmpty ? "-" : f.logLine)
            }
        }
    }

    func stat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k).font(Brand.label(10)).tracking(1.5).foregroundStyle(Brand.dim)
            Text(v).font(.system(size: 17, weight: .semibold).monospacedDigit()).foregroundStyle(Brand.ink).lineLimit(1)
        }
    }
}

struct ResultCard: View {
    let report: FlightReport

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let f = report.result.failure {
                Label(f.title, systemImage: "xmark.circle.fill").font(.headline).foregroundStyle(Brand.ignition)
                Text(f.body).font(.callout)
                Text(String(format: "At %.1f s", f.time)).font(.caption).foregroundStyle(.secondary)
            } else {
                Label("Mission passed", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(Brand.telemetry)
                Text("Score \(report.result.score). Apogee \(Int(report.result.apogee)) m, fuel used \(Int(report.result.fuelUsed)) kg.")
                    .font(.callout)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.hull.opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

import FlightRunner
