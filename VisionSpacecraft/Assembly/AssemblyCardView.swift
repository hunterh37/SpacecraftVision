import SwiftUI
import LabUI
import SpacecraftCore

/// Tip card beside the pad (specs/18): choose Watch build or Build it myself, then step tips with transport.
struct AssemblyCardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let a = model.assembly
        VStack(alignment: .leading, spacing: 14) {
            if !a.active {
                LabHeader(kicker: "\(model.mission.id) · Assembly", title: "Build the rocket", tint: Brand.telemetry)
                Text("Watch it come together, or lift each part into place yourself.")
                    .font(Lab.soft(15)).foregroundStyle(Lab.muted)
                HStack {
                    Button { a.start(.watch, model: model) } label: { Label("Watch build", systemImage: "play.fill") }
                        .buttonStyle(LabPrimaryButton())
                    Button { a.start(.manual, model: model) } label: { Label("Build it myself", systemImage: "hand.raised.fill") }
                        .buttonStyle(LabGhostButton())
                }
            } else if a.done {
                LabHeader(kicker: "Assembly", title: "Craft ready", tint: Brand.telemetry)
                Text("Write the flight code, then take it to the range.").font(Lab.soft(15)).foregroundStyle(Lab.muted)
                HStack {
                    Button("Build again") { a.restart(model) }.buttonStyle(LabGhostButton())
                    Button("Close") { a.stop() }.buttonStyle(LabGhostButton())
                }
            } else if let plan = a.plan, let s = a.current {
                LabCaption("STEP \(a.index + 1) OF \(plan.count)", tint: Brand.telemetry)
                Text(s.instance.definition.displayName + (s.instance.count > 1 ? " x\(s.instance.count)" : ""))
                    .font(Lab.soft(22)).foregroundStyle(Lab.ink)
                Text(a.mode == .manual ? s.tip + " Pinch and hold it on the rack." : s.tip)
                    .font(Lab.soft(15)).foregroundStyle(Lab.ink)
                Text(s.concept).font(Lab.soft(13)).foregroundStyle(Brand.trajectory)
                if let w = a.warning { Text(w).font(Lab.soft(13)).foregroundStyle(Brand.ignition) }
                ProgressView(value: Double(a.index), total: Double(plan.count)).tint(Brand.telemetry)
                if a.mode == .watch { transport(a) } else { manual(a) }
            }
        }
        .padding(24)
        .frame(width: 520)
        .labPanel(corner: 28, tint: Brand.telemetry, variant: .dusk, aurora: 0.3)
    }

    func transport(_ a: AssemblyModel) -> some View {
        HStack(spacing: 10) {
            Button { a.back(model) } label: { Image(systemName: "backward.end.fill") }.buttonStyle(LabIconButton())
            Button { a.playing.toggle() } label: { Image(systemName: a.playing ? "pause.fill" : "play.fill") }.buttonStyle(LabIconButton())
            Button { a.playing = false; a.lock(model) } label: { Image(systemName: "forward.end.fill") }.buttonStyle(LabIconButton())
            Picker("Speed", selection: Binding(get: { a.speed }, set: { a.speed = $0 })) {
                Text("0.5x").tag(0.5); Text("1x").tag(1.0); Text("2x").tag(2.0)
            }
            .pickerStyle(.segmented).frame(width: 170)
            Spacer()
            Button("Take over") { a.takeOver() }.buttonStyle(LabGhostButton())
        }
    }

    func manual(_ a: AssemblyModel) -> some View {
        HStack(spacing: 10) {
            Button { a.back(model) } label: { Image(systemName: "arrow.uturn.backward") }.buttonStyle(LabIconButton())
            Button("Show me") { a.showMe = true }.buttonStyle(LabGhostButton())
            Spacer()
            Button("Exit") { a.stop() }.buttonStyle(LabGhostButton())
        }
    }
}
