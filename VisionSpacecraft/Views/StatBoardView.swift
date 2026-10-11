import SwiftUI
import LabUI
import SpacecraftCore
import TaskGuideCore
import TaskGuideUI

/// Live stat board beside the craft (specs/02 readouts, copy from specs/16 `board.*`).
struct StatBoardView: View {
    @Environment(AppModel.self) private var model
    @State private var targetBounds: [GuidanceTargetID: CGRect] = [:]
    private let guidanceSpace = "StatBoardGuidance"

    var body: some View {
        let s = model.craft.stats()
        let m = model.mission
        VStack(alignment: .leading, spacing: 8) {
            LabHeader(kicker: m.id, title: m.title)
                .guidanceTarget(.missionBrief, coordinateSpaceName: guidanceSpace)
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                row("Wet mass", "\(Int(s.wetMass.rounded())) / \(Int(m.massCap)) kg", warn: s.wetMass > m.massCap)
                row("Dry mass", "\(Int(s.dryMass.rounded())) kg")
                row("TWR", String(format: "%.2f", s.twrSL), warn: s.twrSL < 1)
                row("Delta-v 1", "\(Int(s.deltaVSL)) m/s SL, \(Int(s.deltaVVac)) m/s vac")
                row("Centre of mass", String(format: "%.2f m", s.centerOfMass), dot: .yellow)
                if let cot = s.centerOfThrust { row("Centre of thrust", String(format: "%.2f m", cot), dot: .red) }
                row("Parts", "\(s.partCount) / \(m.partCap)", warn: s.partCount > m.partCap)
                row("Cost", "\(s.cost) / \(m.budget) cr", warn: s.cost > m.budget)
                row("Energy", "\(Int(s.energyWh)) / \(Int(m.energyCap)) Wh")
                row("Lowest heat limit", "\(Int(s.lowestHeatLimit)) K")
            }
            .font(Lab.mono(15))
            Rectangle().fill(Lab.edge.opacity(0.2)).frame(height: 1)
            Group {
                if model.blockers.isEmpty {
                    if s.twrSL < 1 {
                        Label("Thrust to weight below 1.0. The craft will not lift off.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Brand.ignition)
                    } else {
                        LabCaption("Ready to launch", tint: Brand.telemetry)
                    }
                } else {
                    ForEach(model.blockers, id: \.key) { b in
                        VStack(alignment: .leading) {
                            Text("Cannot launch. \(b.title)").bold()
                            Text(b.body).font(.caption)
                        }
                        .foregroundStyle(Lab.danger)
                    }
                    Button("Load reference craft", systemImage: "arrow.uturn.backward") { model.loadReferenceCraft() }
                        .buttonStyle(BrandButtonStyle())
                }
            }
            .guidanceTarget(.statBoard, coordinateSpaceName: guidanceSpace)
        }
        .padding(24)
        .frame(width: 460)
        .font(Lab.soft(15))
        .labPanel(corner: 30, tint: Brand.ignition, variant: .ember, aurora: 0.25)
        .coordinateSpace(name: guidanceSpace)
        .onPreferenceChange(GuidanceTargetBoundsKey.self) { targetBounds = $0 }
        .overlay {
            let active: GuidanceTargetID? = {
                switch model.taskGuideTargetID {
                case .missionBrief, .statBoard: return model.taskGuideTargetID
                default: return nil
                }
            }()
            GuidanceHighlightOverlay(activeID: active, bounds: targetBounds, showsArrow: false)
        }
        .onAppear { model.syncTaskGuideSnapshot() }
    }

    @ViewBuilder
    func row(_ k: String, _ v: String, warn: Bool = false, dot: Color? = nil) -> some View {
        GridRow {
            HStack(spacing: 6) {
                if let dot { Circle().fill(dot).frame(width: 10, height: 10) }
                Text(k.uppercased()).font(Brand.label(11)).tracking(1.5).foregroundStyle(Lab.muted)
            }
            Text(v).foregroundStyle(warn ? Lab.danger : Lab.ink)
        }
    }
}
