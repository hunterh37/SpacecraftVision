import SwiftUI
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
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("VISION SPACECRAFT").font(Brand.display(46)).foregroundStyle(Brand.ink).tracking(4)
                    Text("BUILD · CODE · FLY").font(Brand.label(14)).foregroundStyle(Brand.ignition).tracking(6)
                }
                HStack(spacing: 24) {
                    ForEach(GameMode.allCases) { mode in
                        Button { path.append(mode) } label: { ModeCard(mode: mode, progress: progress(mode)) }
                            .buttonStyle(.plain)
                            .buttonBorderShape(.roundedRectangle(radius: 32))
                            .hoverEffect(.lift)
                    }
                }
            }
            .padding(48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandBackground())
            .toolbar {
                ToolbarItem(placement: .bottomOrnament) {
                    Button("Replay tips", systemImage: "sparkles") { model.walkthrough.replay() }
                }
            }
            .navigationDestination(for: GameMode.self) { ModeView(mode: $0) }
            .navigationDestination(for: Lesson.self) { LessonView(lesson: $0) }
        }
        .tint(Brand.ignition)
        .preferredColorScheme(.dark)
    }

    func progress(_ m: GameMode) -> String {
        switch m {
        case .learn: "\(model.completed.count)/\(Lesson.all.count) LESSONS"
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
        .background(Brand.hull.opacity(0.85), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(mode.tint.opacity(0.35), lineWidth: 1))
        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

private struct ModeView: View {
    let mode: GameMode
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @Environment(\.openWindow) private var openWindow

    var switcher: SpaceSwitcher { SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(mode.line).font(.system(size: 18, weight: .medium)).foregroundStyle(Brand.dim).padding(.bottom, 8)
                switch mode {
                case .learn: lessons
                case .missions: missions
                case .workshop: workshop
                }
            }
            .padding(40)
        }
        .background(BrandBackground())
        .navigationTitle(mode.title)
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
        ForEach(Lesson.all) { l in
            NavigationLink(value: l) {
                Row(index: String(format: "%02d", l.id), title: l.title, detail: l.subtitle, tint: mode.tint) {
                    if let s = model.completed[l.id] {
                        Text(String(repeating: "★", count: s) + String(repeating: "☆", count: 3 - s))
                            .foregroundStyle(Brand.ignition)
                    }
                }
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { model.select(lesson: l) })
        }
    }

    private var missions: some View {
        ForEach(Mission.all) { m in
            Row(index: m.id, title: m.title, detail: summary(m), tint: mode.tint) {
                Button("Fly") {
                    model.mission = m
                    Task { await switcher.show(.range) }
                }
                .buttonStyle(BrandButtonStyle())
            }
            .onTapGesture { model.mission = m }
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(model.mission.id == m.id ? mode.tint : .clear, lineWidth: 2))
        }
    }

    private var workshop: some View {
        VStack(alignment: .leading, spacing: 20) {
            Row(index: model.mission.id, title: "Hangar", detail: "Build for \(model.mission.title). Pick parts, check mass and thrust.", tint: mode.tint) {
                Button("Enter") {
                    Task { await switcher.show(.workshop) }
                    openWindow(id: WindowID.parts)
                }
                .buttonStyle(BrandButtonStyle(tint: mode.tint))
            }
            Row(index: "▶", title: "Range", detail: "Fly the current craft on the launch range.", tint: mode.tint) {
                Button("Launch") { Task { await switcher.show(.range) } }
                    .buttonStyle(BrandButtonStyle(tint: mode.tint))
            }
        }
    }

    private func summary(_ m: Mission) -> String {
        let goal: String
        switch m.goal {
        case let .hop(lo, hi, _): goal = "Apogee \(Int(lo))–\(Int(hi)) m, land in zone"
        case .gates: goal = "\(m.course.gates.count) ring gates in order"
        }
        return "\(goal) · \(Int(m.massCap)) kg · \(m.partCap) parts · \(m.budget) cr"
    }
}

private struct Row<Trailing: View>: View {
    let index: String
    let title: String
    let detail: String
    let tint: Color
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 20) {
            Text(index).font(Brand.label(16)).foregroundStyle(tint).frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Brand.ink)
                Text(detail).font(.system(size: 14)).foregroundStyle(Brand.dim)
            }
            Spacer()
            trailing
        }
        .padding(20)
        .background(Brand.hull.opacity(0.8), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 22, style: .continuous))
        .hoverEffect(.highlight)
    }
}
