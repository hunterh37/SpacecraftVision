import SwiftUI
import LabUI

enum SettingsRoute: Hashable { case main }

/// Settings: guided walkthrough toggle, per-mode replay, full app demo.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var w = model.walkthrough
        TourActionsReader { a in
            Form {
                Section("Launch range sky") {
                    Picker("Sky", selection: Bindable(model).skyStyle) {
                        ForEach(SkyStyle.allCases) { style in Text(style.title).tag(style) }
                    }
                }
                Section {
                    Toggle("Guided walkthroughs", isOn: $w.enabled)
                } footer: {
                    Text("Shows a step-by-step tour the first time each mode and the launch range open. Each step has Show me, which performs the action, and Skip tour.")
                }
                Section("Replay a tour") {
                    ForEach([TourID.range]) { t in
                        HStack {
                            Text(t.title)
                            Spacer()
                            Text(model.walkthrough.isDone(t) ? "Done" : "Not seen").font(.caption).foregroundStyle(.secondary)
                            Button("Replay") {
                                w.enabled = true
                                if t == .range { model.walkthrough.replay(t) }
                                else {
                                    model.showMode(GameMode(rawValue: t.rawValue)!)
                                    model.walkthrough.replay(t)
                                }
                            }
                            .disabled(t == .range && model.openSpace != .range)
                        }
                    }
                    Button("Reset all tours and tips") { w.enabled = true; model.walkthrough.replay() }
                }
                Section {
                    Button("Watch full demo", systemImage: "play.rectangle") {
                        w.enabled = true
                        model.walkthrough.watchFullDemo(a)
                    }
                } footer: {
                    Text("Plays every tour on its own: a lesson from concept to graded flight, a mission into the range, then the hangar. Take over stops it at any step.")
                }
            }
            .scrollContentBackground(.hidden)
            .labWindow()
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .navigationTitle("Settings")
        }
    }
}
