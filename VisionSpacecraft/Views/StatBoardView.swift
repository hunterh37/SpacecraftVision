import SwiftUI
import LabUI
import SpacecraftCore

/// Live stat board beside the craft (specs/02 readouts, copy from specs/16 `board.*`).
struct StatBoardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let s = model.craft.stats()
        let m = model.mission
        VStack(alignment: .leading, spacing: 12) {
            LabHeader("\(m.id) \(m.title)", caption: "Craft readout", tint: Brand.trajectory)
            VStack(spacing: 8) {
                LabStatRow("WET MASS", "\(Int(s.wetMass.rounded())) / \(Int(m.massCap)) kg", warn: s.wetMass > m.massCap)
                LabStatRow("DRY MASS", "\(Int(s.dryMass.rounded())) kg")
                LabStatRow("TWR", String(format: "%.2f", s.twrSL), warn: s.twrSL < 1)
                LabStatRow("DELTA-V", "\(Int(s.deltaVSL)) SL · \(Int(s.deltaVVac)) VAC m/s")
                LabStatRow("CENTRE OF MASS", String(format: "%.2f m", s.centerOfMass), dot: .yellow)
                if let cot = s.centerOfThrust { LabStatRow("CENTRE OF THRUST", String(format: "%.2f m", cot), dot: Lab.danger) }
                LabStatRow("PARTS", "\(s.partCount) / \(m.partCap)", warn: s.partCount > m.partCap)
                LabStatRow("COST", "\(s.cost) / \(m.budget) cr", warn: s.cost > m.budget)
                LabStatRow("ENERGY", "\(Int(s.energyWh)) / \(Int(m.energyCap)) Wh")
                LabStatRow("LOWEST HEAT LIMIT", "\(Int(s.lowestHeatLimit)) K")
            }
            Divider().overlay(Lab.edge.opacity(0.25))
            if model.blockers.isEmpty {
                if s.twrSL < 1 {
                    Label("Thrust to weight below 1.0. The craft will not lift off.", systemImage: "exclamationmark.triangle")
                        .font(Brand.label(12)).foregroundStyle(Brand.ignition)
                } else {
                    Label("READY TO LAUNCH", systemImage: "checkmark.seal").font(Brand.label(12)).tracking(1.5).foregroundStyle(Brand.telemetry)
                }
            } else {
                ForEach(model.blockers, id: \.key) { b in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cannot launch. \(b.title)").font(Brand.label(13))
                        Text(b.body).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Lab.danger)
                }
                Button("Load reference craft", systemImage: "arrow.uturn.backward") { model.loadReferenceCraft() }
                    .buttonStyle(BrandButtonStyle(tint: Brand.trajectory))
            }
        }
        .padding(26)
        .frame(width: 460)
        .labPanel(corner: 32, tint: Brand.trajectory, variant: .dusk, aurora: 0.3)
    }

    @ViewBuilder
    func row(_ k: String, _ v: String, warn: Bool = false, dot: Color? = nil) -> some View {
        GridRow {
            HStack(spacing: 6) {
                if let dot { Circle().fill(dot).frame(width: 10, height: 10) }
                Text(k).foregroundStyle(.secondary)
            }
            Text(v).foregroundStyle(warn ? .red : .primary)
        }
    }
}
