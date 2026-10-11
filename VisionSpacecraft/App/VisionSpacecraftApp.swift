import SwiftUI
import RealKit
import RealLibrary

@main
struct VisionSpacecraftApp: App {
    @State private var model = AppModel()
    @State private var workshopStyle: ImmersionStyle = .full
    @State private var rangeStyle: ImmersionStyle = .full

    init() {
        RealityHD.setup(.balanced)
    }

    var body: some Scene {
        WindowGroup(id: WindowID.main) {
            HomeView()
                .environment(model)
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
