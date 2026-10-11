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
        RealityHD.setup(.balanced)
    }

    var body: some Scene {
        WindowGroup(id: WindowID.main) {
            HomeView()
                .environment(model)
                .modifier(DebugLaunch(model: model))
        }
        .defaultSize(width: 900, height: 700)

        WindowGroup(id: WindowID.parts) {
            PartPickerView()
                .environment(model)
        }
        .defaultSize(width: 520, height: 720)

        WindowGroup(id: WindowID.code) {
            CodeEditorView()
                .environment(model)
        }
        .defaultSize(width: 1000, height: 760)

        WindowGroup(id: WindowID.analysis) {
            AnalysisView()
                .environment(model)
        }
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
        if model.openSpace != nil { await dismiss(); model.openSpace = nil }
        switch await open(id: space.rawValue) {
        case .opened: model.openSpace = space
        default: break
        }
    }

    func close() async {
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
            guard let raw = UserDefaults.standard.string(forKey: "debugLesson"), let n = Int(raw), Lesson.all.indices.contains(n) else { return }
            model.select(lesson: Lesson.all[n])
            openWindow(id: WindowID.code)
            #endif
        }
    }
}
