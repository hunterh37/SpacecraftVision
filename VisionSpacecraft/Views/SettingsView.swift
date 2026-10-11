import SwiftUI
import LabUI

enum SettingsRoute: Hashable { case main }

/// Settings: guided walkthrough toggle, per-mode replay, full app demo.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var w = model.walkthrough
        TourActionsReader { a in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LabHeader(kicker: "RocketCraft", title: "Settings")
                    LabCaption("Launch range sky")
                    HStack {
                        Text("Sky").font(Lab.soft(15))
                        Spacer()
                        LabTabs(items: SkyStyle.allCases, selection: Bindable(model).skyStyle, title: { $0.title })
                    }
                    .labCard(padding: 16)
                    LabCaption("Comfort and sound").padding(.top, 6)
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Comfort vignette in chase view", isOn: Binding(get: { ComfortVignette.enabled }, set: { ComfortVignette.enabled = $0 }))
                            .font(Lab.soft(15)).tint(Brand.telemetry)
                        Text("Darkens the edge of view while the chase camera turns faster than 30 deg/s.")
                            .font(Lab.soft(12)).foregroundStyle(Lab.muted)
                        Toggle("Flight sound", isOn: Binding(get: { FlightAudio.enabled }, set: { FlightAudio.enabled = $0 }))
                            .font(Lab.soft(15)).tint(Brand.telemetry)
                        Text("Engine, propeller and wind sound, and launch, pass and fail cues.")
                            .font(Lab.soft(12)).foregroundStyle(Lab.muted)
                    }
                    .labCard(padding: 16)
                    LabCaption("Walkthroughs").padding(.top, 6)
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Guided walkthroughs", isOn: $w.enabled).font(Lab.soft(15)).tint(Brand.telemetry)
                        Text("Shows a step-by-step tour the first time each mode and the launch range open. Each step has Show me, which performs the action, and Skip tour.")
                            .font(Lab.soft(12)).foregroundStyle(Lab.muted)
                    }
                    .labCard(padding: 16)
                    LabCaption("Replay a tour", tint: Brand.trajectory).padding(.top, 6)
                    VStack(spacing: 10) {
                        ForEach(TourID.allCases) { t in
                            HStack {
                                Text(t.title).font(Lab.soft(15))
                                Spacer()
                                Text(model.walkthrough.isDone(t) ? "DONE" : "NOT SEEN").font(Brand.label(11)).tracking(1.5)
                                    .foregroundStyle(model.walkthrough.isDone(t) ? Brand.telemetry : Lab.faint)
                                Button("Replay") {
                                    w.enabled = true
                                    if t == .range { model.walkthrough.replay(t) }
                                    else {
                                        model.showMode(GameMode(rawValue: t.rawValue)!)
                                        model.walkthrough.replay(t)
                                    }
                                }
                                .buttonStyle(LabGhostButton())
                                .disabled(t == .range && model.openSpace != .range)
                            }
                        }
                        Button("Reset all tours and tips") { w.enabled = true; model.walkthrough.replay() }
                            .buttonStyle(LabGhostButton(tint: Brand.ignition))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .labCard(padding: 16)
                    LabCaption("Demo", tint: Brand.ignition).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            w.enabled = true
                            model.walkthrough.watchFullDemo(a)
                        } label: { Label("WATCH FULL DEMO", systemImage: "play.rectangle") }
                        .buttonStyle(BrandButtonStyle())
                        Text("Plays every tour on its own: a lesson from concept to graded flight, a mission into the range, then the hangar. Take over stops it at any step.")
                            .font(Lab.soft(12)).foregroundStyle(Lab.muted)
                    }
                    .labCard(padding: 16)
                }
                .padding(32)
            }
            .labWindow(tint: Brand.telemetry, variant: .dusk, aurora: 0.16)
            .navigationTitle("Settings")
        }
    }
}
