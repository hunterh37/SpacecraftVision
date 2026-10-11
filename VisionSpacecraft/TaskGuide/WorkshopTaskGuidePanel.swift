import SwiftUI
import TaskGuideCore
import TaskGuideUI

struct WorkshopTaskGuidePanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace

    private var switcher: SpaceSwitcher {
        SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace)
    }

    var body: some View {
        TaskBoardView(
            controller: model.taskGuide,
            host: TaskGuideBridge.hostContext(mission: model.mission, controller: model.taskGuide),
            onOpenParts: { openWindow(id: WindowID.parts) },
            onGoToLaunchRange: {
                model.endGuidedWorkshop()
                Task { await switcher.show(.range) }
            },
            onExitGuide: {
                model.endGuidedWorkshop()
            }
        )
        .onChange(of: model.craft) { _, _ in model.syncTaskGuideSnapshot() }
        .onChange(of: model.mission.id) { _, _ in model.syncTaskGuideSnapshot() }
        .onChange(of: model.workshopTabletop) { _, _ in model.syncTaskGuideSnapshot() }
    }
}
