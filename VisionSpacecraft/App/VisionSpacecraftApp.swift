import SwiftUI
import RealKit
import RealLibrary
import Curriculum

@main
struct VisionSpacecraftApp: App {
    @State private var model = AppModel()
    @State private var workshopStyle: ImmersionStyle = .full
    @State private var rangeStyle: ImmersionStyle = .full
    @State private var spaceStyle: ImmersionStyle = .full

    init() {
        LoosePartComponent.registerComponent()
        RealityHD.setup(.balanced)
    }

    var body: some Scene {
        WindowGroup(id: WindowID.main) {
            HomeView()
                .environment(model)
                .overlay { SceneLoadingOverlay(space: model.loadingSpace) }
                .modifier(DebugLaunch(model: model))
        }
        .windowStyle(.plain)
        .defaultSize(width: 900, height: 700)

        WindowGroup(id: WindowID.parts) {
            PartPickerView()
                .environment(model)
        }
        .windowStyle(.plain)
        .defaultSize(width: 520, height: 720)

        WindowGroup(id: WindowID.code) {
            CodeEditorView()
                .environment(model)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1000, height: 760)

        WindowGroup(id: WindowID.analysis) {
            AnalysisView()
                .environment(model)
        }
        .windowStyle(.plain)
        .defaultSize(width: 900, height: 640)

        ImmersiveSpace(id: SpaceID.workshop.rawValue) {
            WorkshopImmersiveView()
                .environment(model)
        }
        .immersionStyle(selection: $workshopStyle, in: .mixed, .full)

        ImmersiveSpace(id: SpaceID.range.rawValue) {
            RangeImmersiveView()
                .environment(model)
        }
        .immersionStyle(selection: $rangeStyle, in: .full)

        ImmersiveSpace(id: SpaceID.space.rawValue) {
            SpaceImmersiveView()
                .environment(model)
        }
        .immersionStyle(selection: $spaceStyle, in: .full)
    }
}

/// Opens one immersive space at a time.
@MainActor
struct SpaceSwitcher {
    let model: AppModel
    let open: OpenImmersiveSpaceAction
    let dismiss: DismissImmersiveSpaceAction

    func show(_ space: SpaceID) async {
        if model.openSpace == space { return }
        let previous = model.openSpace
        // Clear Workshop guidance before opening an unrelated scene (avoid stale tour restore while openSpace is still .workshop).
        if previous == .workshop, space != .workshop {
            model.leaveWorkshopImmersive(for: space)
        }
        model.loadingSpace = space
        if model.openSpace != nil { await dismiss(); model.openSpace = nil }
        switch await open(id: space.rawValue) {
        case .opened: model.openSpace = space
        default: model.loadingSpace = nil
        }
    }

    func close() async {
        if model.openSpace == .workshop {
            model.leaveWorkshopImmersive(for: nil)
        }
        if model.openSpace != nil { await dismiss(); model.openSpace = nil }
    }
}

/// Debug builds only: `-debugLesson N` selects lesson N and opens the code window at launch, for simulator screenshots.
private struct DebugLaunch: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    let model: AppModel
    func body(content: Content) -> some View {
        content.task {
            #if DEBUG
            // -debugRange 1 opens the launch scene directly for simulator visual checks.
            if UserDefaults.standard.string(forKey: "debugRange") == "1" {
                try? await Task.sleep(for: .seconds(2))
                await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.range)
                return
            }
            // -debugSpace N [-debugCode ref|starter] [-debugLaunch 1]: open the space scene on lesson N, optionally flying it at 8x.
            if let raw = UserDefaults.standard.string(forKey: "debugSpace"), let n = Int(raw), Lesson.all.indices.contains(n) {
                let l = Lesson.all[n]
                model.select(lesson: l)
                model.source = UserDefaults.standard.string(forKey: "debugCode") == "starter" ? l.starterCode : l.referenceCode
                try? await Task.sleep(for: .seconds(2))
                await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.space)
                if UserDefaults.standard.string(forKey: "debugLaunch") == "1" { try? await Task.sleep(for: .seconds(2)); model.flight.timeScale = 8; model.launch() }
                return
            }
            // -debugRoute learn | missions | workshop | lessonN-stage | analysis | parts | settings | code: jump to a screen for visual checks.
            if let route = UserDefaults.standard.string(forKey: "debugRoute") {
                let l1 = Lesson.all[min(1, Lesson.all.count - 1)]
                model.select(lesson: l1)
                model.source = l1.referenceCode
                switch route {
                case "learn", "missions", "workshop": model.showMode(GameMode(rawValue: route)!)
                case "settings": model.homePath = NavigationPath(); model.homePath.append(SettingsRoute.main)
                case "parts": openWindow(id: WindowID.parts)
                case "code": openWindow(id: WindowID.code)
                case "analysis":
                    for _ in 0..<40 { if model.preview?.compileError == nil, model.preview != nil { break }; try? await Task.sleep(for: .milliseconds(250)) }
                    model.lastReport = model.preview; model.reports = model.preview.map { [$0] } ?? []
                    openWindow(id: WindowID.analysis)
                default:
                    if route.hasPrefix("lesson") {
                        let parts = route.dropFirst(6).split(separator: "-")
                        if let i = parts.first.flatMap({ Int($0) }), Lesson.all.indices.contains(i) {
                            model.select(lesson: Lesson.all[i]); model.showMode(.learn); model.homePath.append(Lesson.all[i])
                            if let st = parts.dropFirst().first, let stage = LessonStage.allCases.first(where: { String(describing: $0) == st }) { model.lessonStage = stage }
                        }
                    }
                }
                return
            }
            guard let raw = UserDefaults.standard.string(forKey: "debugLesson"), let n = Int(raw), Lesson.all.indices.contains(n) else { return }
            model.select(lesson: Lesson.all[n])
            openWindow(id: WindowID.code)
            #endif
        }
    }
}

/// Progress indicator shown while an immersive space generates its assets.
struct SceneLoadingOverlay: View {
    let space: SpaceID?
    var body: some View {
        if space != nil {
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text("Loading scene").font(.headline)
            }
            .padding(32)
            .glassBackgroundEffect()
            .transition(.opacity)
        }
    }
}
