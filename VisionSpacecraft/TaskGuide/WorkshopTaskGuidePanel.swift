import SwiftUI
import TaskGuideCore
import TaskGuideUI

/// Workshop attachment hosting the shared Task Guide panel.
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
                // Close Guided Build so Walkthrough range prompts can start again.
                model.endGuidedBuild()
                Task { await switcher.show(.range) }
            },
            onExitGuide: {
                model.endGuidedBuild()
            }
        )
        .onChange(of: model.craft) { _, _ in model.syncTaskGuideSnapshot() }
        .onChange(of: model.mission) { _, _ in model.syncTaskGuideSnapshot() }
    }
}
