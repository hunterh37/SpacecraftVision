import SwiftUI
import LabUI
import SpacecraftCore
import Curriculum

enum GameMode: String, CaseIterable, Identifiable, Hashable {
    case learn, missions, workshop
    var id: String { rawValue }
    var title: String { switch self { case .learn: "Learn"; case .missions: "Missions"; case .workshop: "Workshop" } }
    var line: String {
        switch self {
        case .learn: "Code a flight, one idea at a time"
        case .missions: "Build to a brief. Fly the range"
        case .workshop: "Free build at life size"
        }
    }
    var symbol: String {
        switch self {
        case .learn: "chevron.left.forwardslash.chevron.right"
        case .missions: "flag.checkered"
        case .workshop: "wrench.and.screwdriver"
        }
    }
    var tint: Color { switch self { case .learn: Brand.telemetry; case .missions: Brand.ignition; case .workshop: Brand.trajectory } }
}

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.homePath) {
            VStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("VISION SPACECRAFT").font(Brand.display(46)).foregroundStyle(Brand.ink).tracking(4)
                    Text("BUILD · CODE · FLY").font(Brand.label(14)).foregroundStyle(Brand.ignition).tracking(6)
                }
                HStack(spacing: 24) {
                    ForEach(GameMode.allCases) { mode in
                        Button { model.homePath.append(mode) } label: { ModeCard(mode: mode, progress: progress(mode)) }
                            .buttonStyle(.plain)
                            .buttonBorderShape(.roundedRectangle(radius: 32))
                            .hoverEffect(.lift)
                    }
                }
            }
            .padding(48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .labWindow()
            .toolbarVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .bottomOrnament) {
                    Button("Settings", systemImage: "gearshape") { model.homePath.append(SettingsRoute.main) }
                }
            }
            .navigationDestination(for: GameMode.self) { ModeView(mode: $0) }
            .navigationDestination(for: Lesson.self) { LessonView(lesson: $0) }
            .navigationDestination(for: SettingsRoute.self) { _ in SettingsView() }
        }
        .task {
            // Evaluates tour predicates while the range is closed.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                if model.openSpace != .range { model.walkthrough.tick(model: model) }
            }
        }
        .tint(Brand.ignition)
        .preferredColorScheme(.dark)
    }

    func progress(_ m: GameMode) -> String {
        switch m {
        case .learn: "\(min(model.completed.count, 1))/1 LESSON · MORE SOON"
        case .missions: "\(Mission.all.count) MISSIONS"
        case .workshop: "\(model.craft.stack.count) PARTS ON PAD"
        }
    }
}

private struct ModeCard: View {
    let mode: GameMode
    let progress: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: mode.symbol)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(mode.tint)
                .frame(width: 72, height: 72)
                .background(mode.tint.opacity(0.14), in: Circle())
            Spacer()
            Text(mode.title.uppercased()).font(Brand.display(26)).foregroundStyle(Brand.ink)
            Text(mode.line).font(.system(size: 16, weight: .medium)).foregroundStyle(Brand.dim)
            Rectangle().fill(mode.tint).frame(width: 36, height: 3)
            Text(progress).font(Brand.label(12)).foregroundStyle(mode.tint).tracking(2)
        }
        .padding(28)
        .frame(width: 250, height: 320, alignment: .leading)
        .labPanel(corner: 32, tint: mode.tint, variant: mode == .missions ? .ember : mode == .workshop ? .dusk : .tide, aurora: 0.22)
        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

private struct ModeView: View {
    let mode: GameMode
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var switcher: SpaceSwitcher { SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LabHeader(mode.title, caption: mode.line, tint: mode.tint, onBack: { dismiss() }).padding(.bottom, 6)
                switch mode {
                case .learn: lessons
                case .missions: missions
                case .workshop: workshop
                }
            }
            .padding(40)
        }
        .labWindow(tint: mode.tint)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
                Button("Code", systemImage: "chevron.left.forwardslash.chevron.right") { openWindow(id: WindowID.code) }
                Button("Analysis", systemImage: "chart.xyaxis.line") { openWindow(id: WindowID.analysis) }
                if model.openSpace != nil {
                    Button("Exit space", systemImage: "xmark") { Task { await switcher.close() } }
                }
            }
        }
    }

    private var lessons: some View {
        VStack(spacing: 14) {
            if let l = Lesson.all.first {
                NavigationLink(value: l) {
                    LabRow(index: "01", title: l.title, detail: l.subtitle, tint: mode.tint) {
                        if let st = model.completed[l.id] {
                            Text(String(repeating: "★", count: st) + String(repeating: "☆", count: 3 - st)).foregroundStyle(Brand.ignition)
                        } else {
                            Text("START").font(Brand.label(12)).tracking(2).foregroundStyle(mode.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { model.select(lesson: l) })
            }
            ForEach(Array(ComingSoon.lessons.enumerated()), id: \.offset) { i, c in
                LabRow(index: String(format: "%02d", i + 2), title: c.title, detail: c.detail, tint: Brand.dim) {
                    Label("SOON", systemImage: "lock.fill").font(Brand.label(11)).tracking(2).foregroundStyle(Brand.dim)
                }
                .opacity(0.55)
                .allowsHitTesting(false)
            }
        }
    }

    private var missions: some View {
        ForEach(Mission.all) { m in
            LabRow(index: m.id, title: m.title, detail: summary(m), tint: mode.tint, selected: model.mission.id == m.id) {
                HStack {
                    Button("Code") {
                        model.mission = m
                        model.missionPicked = true
                        openWindow(id: WindowID.code)
                    }
                    Button("Fly") {
                        model.mission = m
                        model.missionPicked = true
                        Task { await switcher.show(.range) }
                    }
                    .buttonStyle(BrandButtonStyle())
                }
            }
            .onTapGesture { model.mission = m; model.missionPicked = true }
        }
    }

    private var workshop: some View {
        VStack(alignment: .leading, spacing: 20) {
            LabRow(index: model.mission.id, title: "Hangar", detail: "Build for \(model.mission.title). Pick parts, check mass and thrust.", tint: mode.tint) {
                Button("Enter") {
                    Task { await switcher.show(.workshop) }
                    openWindow(id: WindowID.parts)
                }
                .buttonStyle(BrandButtonStyle(tint: mode.tint))
            }
            LabRow(index: "▶", title: "Range", detail: "Fly the current craft on the launch range.", tint: mode.tint) {
                Button("Launch") { Task { await switcher.show(.range) } }
                    .buttonStyle(BrandButtonStyle(tint: mode.tint))
            }
        }
    }

    private func summary(_ m: Mission) -> String {
        if let challenge = AlgorithmChallenge.named(m.id) {
            return "\(challenge.strategy) · \(challenge.buildReason)"
        }
        let goal: String
        switch m.goal {
        case let .hop(lo, hi, _): goal = "Apogee \(Int(lo))–\(Int(hi)) m, land in zone"
        case .gates: goal = "\(m.course.gates.count) ring gates in order"
        }
        return "\(goal) · \(Int(m.massCap)) kg · \(m.partCap) parts · \(m.budget) cr"
    }
}

/// Lessons shown as locked so the course reads as a whole; none of them is built yet.
private struct ComingSoon {
    let title: String
    let detail: String
    static let lessons: [ComingSoon] = [
        ComingSoon(title: "Reactive avoidance", detail: "Sense with rays and steer around what is in the way"),
        ComingSoon(title: "Potential fields", detail: "The goal pulls, obstacles push, the craft follows the force"),
        ComingSoon(title: "Vector field histogram", detail: "Pick the widest safe gap from a polar scan"),
        ComingSoon(title: "Path planning", detail: "Search a grid of free space and replan as it changes"),
    ]
}
