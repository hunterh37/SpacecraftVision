import SwiftUI
import SpacecraftCore
import Curriculum

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationStack {
            List {
                Section("Lessons") {
                    ForEach(Lesson.all) { l in
                        NavigationLink(value: l) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(l.id). \(l.title)").font(.headline)
                                    Text(l.subtitle).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let stars = model.completed[l.id] {
                                    Text(String(repeating: "★", count: stars) + String(repeating: "☆", count: 3 - stars))
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                    }
                }
                Section("Missions") {
                    ForEach(Mission.all) { m in
                        Button {
                            model.mission = m
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(m.id) \(m.title)").font(.headline)
                                    Text(missionSummary(m)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.mission.id == m.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
                            }
                        }
                    }
                }
                Section("Open") {
                    HStack(spacing: 12) {
                        Button("Workshop", systemImage: "wrench.and.screwdriver") {
                            Task { await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.workshop) }
                            openWindow(id: WindowID.parts)
                        }
                        Button("Range", systemImage: "flag.checkered") {
                            Task { await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.range) }
                        }
                        Button("Code", systemImage: "chevron.left.forwardslash.chevron.right") { openWindow(id: WindowID.code) }
                        Button("Analysis", systemImage: "chart.xyaxis.line") { openWindow(id: WindowID.analysis) }
                        if model.openSpace != nil {
                            Button("Exit space", systemImage: "xmark") {
                                Task { await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).close() }
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Vision Spacecraft")
            .navigationDestination(for: Lesson.self) { l in
                LessonView(lesson: l)
            }
        }
    }

    func missionSummary(_ m: Mission) -> String {
        let goal: String
        switch m.goal {
        case let .hop(lo, hi, _): goal = "Apogee \(Int(lo)) to \(Int(hi)) m, land in the zone"
        case .gates: goal = "Pass \(m.course.gates.count) ring gates in order"
        }
        return "\(goal). Mass cap \(Int(m.massCap)) kg, \(m.partCap) parts, \(m.budget) cr."
    }
}
