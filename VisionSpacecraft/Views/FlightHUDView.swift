import SwiftUI
import LabUI
import SpacecraftCore
import FlightSim
import FlightRunner

/// Range HUD. One primary action per state; everything else is revealed on demand or as the tour advances.
/// States: blocked -> Fix craft, code error -> Open code, ready -> Launch, flying -> Pause, finished -> Debrief / Fly again.
struct FlightHUDView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @State private var details = false
    @State private var debriefed = false

    /// Tour step id, or nil once the tour is done. Controls appear as the tour reaches them.
    private var tourStep: Int? { model.walkthrough.current?.id }
    private func revealed(_ step: Int) -> Bool { tourStep.map { $0 >= step } ?? true }

    var body: some View {
        let f = model.flight
        VStack(alignment: .leading, spacing: 16) {
            header
            status(f)
            if details { detail(f).transition(.opacity.combined(with: .move(edge: .top))) }
            controls(f)
        }
        .padding(22)
        .frame(width: 520)
        .labPanel(corner: 30, tint: Brand.ignition, variant: .ember, aurora: 0.28)
        .tint(Brand.ignition)
        .animation(.spring(duration: 0.35), value: f.phase)
        .animation(.spring(duration: 0.35), value: details)
        .animation(.spring(duration: 0.35), value: tourStep)
        .onChange(of: f.launchID) { debriefed = false; details = false }
        .onChange(of: model.analysisOpened) { if f.phase == .finished { debriefed = true } }
    }

    // MARK: Header: mission id, title, view cycle

    var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(model.mission.id).font(Brand.label(13)).foregroundStyle(Brand.ignition).tracking(2)
            Text(model.mission.title.uppercased()).font(Brand.display(19)).foregroundStyle(Brand.ink).lineLimit(1)
            Spacer()
            if revealed(4) {
                Button { cycleView() } label: {
                    Label(model.flightView.label, systemImage: viewIcon).font(Brand.label(12))
                }
                .buttonStyle(.bordered).buttonBorderShape(.capsule)
                .accessibilityHint("Switches between ground, chase and tabletop views")
                .transition(.opacity)
            }
        }
    }

    var viewIcon: String {
        switch model.flightView { case .ground: "person.fill"; case .chase: "airplane"; case .tabletop: "square.grid.3x3.topleft.filled" }
    }

    func cycleView() {
        let all = FlightView.allCases
        model.flightView = all[(all.firstIndex(of: model.flightView)! + 1) % all.count]
    }

    // MARK: Status: one line before flight, three numbers in flight, one verdict after

    @ViewBuilder func status(_ f: FlightController) -> some View {
        switch f.phase {
        case .idle:
            Button { details.toggle() } label: {
                HStack(spacing: 10) {
                    Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(ready ? Brand.telemetry : Brand.ignition)
                    Text(statusLine).font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Brand.ink).lineLimit(2).multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Image(systemName: details ? "chevron.up" : "chevron.down").font(.footnote).foregroundStyle(Brand.dim)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows preflight checks")
        case .flying, .paused:
            HStack(spacing: 0) {
                big("ALT", "\(Int(f.altitude))", "m")
                big("SPEED", "\(Int(f.speed))", "m/s")
                if model.mission.course.gates.isEmpty { big("FUEL", "\(Int(f.fuel * 100))", "%") }
                else { big("GATES", "\(f.gates)", "/\(model.mission.course.gates.count)") }
            }
            .onTapGesture { details.toggle() }
        case .finished:
            if let r = model.lastReport {
                let pass = r.result.passed
                HStack(spacing: 10) {
                    Image(systemName: pass ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2).foregroundStyle(pass ? Brand.telemetry : Brand.ignition)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pass ? "Mission passed" : r.result.failure?.title ?? "Failed")
                            .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Brand.ink)
                        Text(pass ? "Score \(r.result.score)" : String(format: "At %.1f s", r.result.failure?.time ?? 0))
                            .font(Brand.label(12)).foregroundStyle(Brand.dim)
                    }
                }
            }
        }
    }

    func big(_ k: String, _ v: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(k).font(Brand.label(10)).tracking(1.5).foregroundStyle(Brand.dim)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(v).font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Brand.ink).contentTransition(.numericText())
                Text(unit).font(Brand.label(12)).foregroundStyle(Brand.dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var compiled: Bool { if case .error = model.compileStatus { return false }; return true }
    var ready: Bool { model.blockers.isEmpty && compiled }

    var statusLine: String {
        if let b = model.blockers.first { return b.title }
        if case let .error(e) = model.compileStatus { return "Code error, line \(e.line)" }
        guard let p = model.preview else { return "Predicting…" }
        if let fail = p.result.failure { return "Ready. Predicted: \(fail.title)" }
        return "Ready. Predicted pass, \(Int(p.result.apogee)) m"
    }

    // MARK: Detail (on demand)

    struct Check: Identifiable { let id: String; let label: String; let value: String; let ok: Bool }

    var checks: [Check] {
        let s = model.craft.stats(), m = model.mission
        let keys = Set(model.blockers.map(\.key))
        return [
            Check(id: "command", label: "COMMAND", value: s.hasCommand ? "Probe core" : "None", ok: !keys.contains("fail.command")),
            Check(id: "mass", label: "MASS", value: "\(Int(s.wetMass.rounded()))/\(Int(m.massCap)) kg", ok: !keys.contains("fail.mass")),
            Check(id: "parts", label: "PARTS", value: "\(s.partCount)/\(m.partCap)", ok: !keys.contains("fail.part-list")),
            Check(id: "budget", label: "BUDGET", value: "\(s.cost)/\(m.budget) cr", ok: !keys.contains("fail.budget")),
            Check(id: "code", label: "CODE", value: compiled ? "OK" : "Error", ok: compiled),
        ]
    }

    @ViewBuilder func detail(_ f: FlightController) -> some View {
        switch f.phase {
        case .idle:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(checks) { c in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.label).font(Brand.label(9)).tracking(1).foregroundStyle(c.ok ? Brand.dim : Brand.ignition)
                            Text(c.value).font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(c.ok ? Brand.ink : Brand.ignition).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Brand.hull.opacity(0.8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                if let b = model.blockers.first {
                    Text(b.body).font(.callout).foregroundStyle(Brand.dim).fixedSize(horizontal: false, vertical: true)
                } else if let fail = model.preview?.result.failure {
                    Text(fail.body).font(.callout).foregroundStyle(Brand.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
        case .flying, .paused:
            HStack(spacing: 0) {
                small("THROTTLE", "\(Int(f.throttle * 100))%")
                small("ENERGY", "\(Int(f.energy * 100))%")
                small("TIME", String(format: "%.1f s", f.time))
                small("STATE", f.logLine.isEmpty ? "-" : f.logLine)
            }
        case .finished:
            if let r = model.lastReport {
                Text(r.result.failure?.body ?? "Apogee \(Int(r.result.apogee)) m. Fuel \(Int(r.result.fuelUsed)) kg.")
                    .font(.callout).foregroundStyle(Brand.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func small(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k).font(Brand.label(9)).tracking(1.5).foregroundStyle(Brand.dim)
            Text(v).font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(Brand.ink).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Controls: one primary, quiet secondaries

    @ViewBuilder func controls(_ f: FlightController) -> some View {
        HStack(spacing: 10) {
            if f.phase == .flying || f.phase == .paused {
                iconButton("xmark", "Abort") { f.abort() }
                iconButton(speedIcon(f.timeScale), "Time \(speedLabel(f.timeScale))") { f.timeScale = nextSpeed(f.timeScale) }
                    .overlay(alignment: .bottom) {
                        Text(speedLabel(f.timeScale)).font(Brand.label(9)).foregroundStyle(Brand.telemetry).offset(y: 14)
                    }
            }
            if tourStep == nil {
                if f.phase != .flying && f.phase != .paused {
                    iconButton("chevron.left.forwardslash.chevron.right", "Code") { openWindow(id: WindowID.code) }
                }
                if f.phase == .finished && !debriefed {
                    iconButton("arrow.counterclockwise", "Reset") { f.reset() }
                }
            }
            Spacer()
            if showsPrimary(f) { primary(f) }
        }
    }

    /// Hidden only on the first two tour steps (pad, path), which advance from the callout.
    func showsPrimary(_ f: FlightController) -> Bool { revealed(2) }

    @ViewBuilder func primary(_ f: FlightController) -> some View {
        switch f.phase {
        case .idle:
            if !model.blockers.isEmpty {
                Button("Fix craft", systemImage: "wrench.fill") { model.loadReferenceCraft() }
                    .buttonStyle(BrandButtonStyle(tint: .white))
                    .contextMenu {
                        Button("Open hangar", systemImage: "hammer") {
                            Task { await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.workshop) }
                            openWindow(id: WindowID.parts)
                        }
                    }
            } else if !compiled {
                Button("Open code", systemImage: "chevron.left.forwardslash.chevron.right") { openWindow(id: WindowID.code) }
                    .buttonStyle(BrandButtonStyle(tint: .white))
            } else {
                Button("Launch", systemImage: "flame.fill") { model.launch() }.buttonStyle(BrandButtonStyle())
            }
        case .flying:
            Button("Pause", systemImage: "pause.fill") { f.togglePause() }.buttonStyle(BrandButtonStyle(tint: .white))
        case .paused:
            Button("Resume", systemImage: "play.fill") { f.togglePause() }.buttonStyle(BrandButtonStyle())
        case .finished:
            if debriefed {
                Button("Fly again", systemImage: "flame.fill") { f.reset(); model.launch() }.buttonStyle(BrandButtonStyle())
            } else {
                Button(model.lastReport?.result.passed == true ? "Debrief" : "See why", systemImage: "chart.xyaxis.line") {
                    openWindow(id: WindowID.analysis)
                    debriefed = true
                }
                .buttonStyle(BrandButtonStyle())
            }
        }
    }

    func iconButton(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 16, weight: .semibold)).frame(width: 22, height: 22) }
            .buttonStyle(.bordered).buttonBorderShape(.circle)
            .accessibilityLabel(label)
            .help(label)
    }

    func nextSpeed(_ s: Double) -> Double { s == 1 ? 0.25 : s == 0.25 ? 4 : 1 }
    func speedLabel(_ s: Double) -> String { s == 0.25 ? "0.25x" : s == 4 ? "4x" : "1x" }
    func speedIcon(_ s: Double) -> String { s == 0.25 ? "tortoise.fill" : s == 4 ? "hare.fill" : "gauge.with.dots.needle.50percent" }
}

struct ResultCard: View {
    let report: FlightReport

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let f = report.result.failure {
                LabCaption(f.title, tint: Brand.ignition)
                Text(f.body).font(Lab.soft(15)).foregroundStyle(Lab.ink)
                Text(String(format: "AT %.1f S", f.time)).font(Brand.label(11)).tracking(2).foregroundStyle(Lab.muted)
            } else {
                LabCaption("Mission passed", tint: Brand.telemetry)
                Text("Score \(report.result.score). Apogee \(Int(report.result.apogee)) m, fuel used \(Int(report.result.fuelUsed)) kg.")
                    .font(Lab.soft(15)).foregroundStyle(Lab.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .labCard(tint: report.result.failure == nil ? Brand.telemetry : Brand.ignition, corner: 16, padding: 14)
    }
}
