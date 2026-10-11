import SwiftUI
import LabUI
import SpacecraftCore

/// Part palette (specs/02): mission-allowed parts, the current stack top to bottom with radial parts,
/// fuel load per tank, reorder and remove.
struct PartPickerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LabHeader(kicker: "\(model.mission.id) · Hangar", title: "Parts", tint: Brand.trajectory)
                TipBanner(tip: .hangar)
                budgetMeter.labCard(padding: 16)
                LabCaption("Rack: \(model.mission.id) parts", tint: Brand.trajectory).padding(.top, 4)
                ForEach(model.mission.allowedParts, id: \.self) { id in
                    if let def = PartCatalog.part(id) {
                        let block = model.addBlock(id)
                        Button { model.addPart(id) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icon(def.category)).font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Brand.trajectory).frame(width: 36, height: 36)
                                    .background(Brand.trajectory.opacity(0.14), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(def.displayName).font(Lab.soft(15)).foregroundStyle(Lab.ink)
                                    Text(block ?? detail(def)).font(Lab.mono(11))
                                        .foregroundStyle(block == nil ? Lab.muted : Brand.ignition)
                                }
                                Spacer()
                                Text("\(def.cost) CR").font(Brand.label(12)).foregroundStyle(Brand.telemetry)
                            }
                            .labCard(corner: 16, padding: 12)
                            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.highlight)
                        .disabled(block != nil)
                        .opacity(block == nil ? 1 : 0.6)
                    }
                }
                LabCaption("Stack, top to bottom", tint: Brand.telemetry).padding(.top, 4)
                if model.craft.stack.isEmpty { Text("Empty. Add a probe core first.").font(Lab.soft(14)).foregroundStyle(Lab.muted) }
                ForEach(model.craft.stack) { p in
                    let selected = model.selectedStackPart == p.id
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(p.definition.displayName).font(Lab.soft(15)).foregroundStyle(selected ? Brand.telemetry : Lab.ink)
                            Spacer()
                            Button { model.moveStack(p.id, by: -1) } label: { Image(systemName: "arrow.up") }.buttonStyle(LabIconButton())
                            Button { model.moveStack(p.id, by: 1) } label: { Image(systemName: "arrow.down") }.buttonStyle(LabIconButton())
                            Button(role: .destructive) { model.removeStack(p.id) } label: { Image(systemName: "trash").foregroundStyle(Lab.danger) }.buttonStyle(LabIconButton())
                        }
                        if p.definition.propellantMass > 0 {
                            HStack {
                                Text("FUEL \(Int((p.fuelLoad * 100).rounded()))%").font(Brand.label(11)).tracking(1.5).foregroundStyle(Lab.muted)
                                Slider(value: Binding(get: { p.fuelLoad }, set: { model.setFuel(p.id, ($0 * 20).rounded() / 20) }),
                                       in: 0...1, step: 0.05)
                                    .tint(Brand.ignition)
                                    .disabled(model.mission.fixedFuelLoad != nil)
                            }
                            if model.mission.fixedFuelLoad != nil {
                                Text("Fuel load fixed by the mission.").font(Lab.soft(11)).foregroundStyle(Lab.faint)
                            }
                        }
                        ForEach(model.craft.radial.filter { $0.parentId == p.id }) { r in
                            HStack {
                                Text("+ \(r.definition.displayName)\(r.count > 1 ? " x\(r.count)" : "")").font(Lab.mono(12)).foregroundStyle(Lab.muted)
                                Spacer()
                                Button(role: .destructive) { model.removeRadial(r.id) } label: { Image(systemName: "minus") }.buttonStyle(LabIconButton())
                            }
                            .padding(.leading, 12)
                        }
                    }
                    .labCard(tint: selected ? Brand.telemetry : Lab.edge, corner: 16, padding: 12)
                    .contentShape(Rectangle())
                    .onTapGesture { model.selectedStackPart = p.id }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Tabletop scale", isOn: $model.workshopTabletop).font(Lab.soft(15)).tint(Brand.telemetry)
                    HStack {
                        Button("Load reference craft") { model.loadReferenceCraft() }.buttonStyle(LabGhostButton())
                        Button("Load Saturn V") { model.loadSaturnV() }.buttonStyle(LabGhostButton())
                        Spacer()
                        Button("Clear craft", role: .destructive) { model.clearCraft() }.buttonStyle(LabGhostButton(tint: Lab.danger))
                    }
                }
                .labCard(padding: 16)
                .padding(.top, 4)
            }
            .padding(24)
        }
        .labWindow(tint: Brand.trajectory, variant: .dusk, aurora: 0.16)
    }

    var budgetMeter: some View {
        let s = model.craft.stats(), m = model.mission
        let left = m.budget - s.cost
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BUDGET").font(Brand.label(11)).tracking(3).foregroundStyle(Brand.dim)
                Spacer()
                Text(left >= 0 ? "\(left) cr left" : "\(-left) cr over")
                    .font(Brand.label(13)).foregroundStyle(left >= 0 ? Brand.telemetry : Brand.ignition)
            }
            ProgressView(value: min(Double(s.cost), Double(m.budget)), total: Double(m.budget))
                .tint(left >= 0 ? Brand.telemetry : Brand.ignition)
            Text("\(s.cost) / \(m.budget) cr · \(s.partCount) / \(m.partCap) parts · \(Int(s.wetMass)) / \(Int(m.massCap)) kg")
                .font(Lab.mono(11)).foregroundStyle(Lab.muted)
        }
    }

    func icon(_ c: PartCategory) -> String {
        switch c {
        case .command: "cpu"; case .tank: "fuelpump"; case .engine: "flame"; case .aero: "triangle"
        case .structure: "square.stack.3d.up"; case .recovery: "parachute"; case .power: "battery.100"; case .sensor: "dot.radiowaves.left.and.right"
        }
    }

    func detail(_ d: PartDefinition) -> String {
        var s = "\(fmtMass(d.dryMass)) kg dry"
        if d.propellantMass > 0 { s += ", \(Int(d.wetMass)) kg wet" }
        if let e = d.engine { s += ", \(Int(e.thrustSL / 1000 * 10) / 10) kN SL, Isp \(Int(e.ispSL))/\(Int(e.ispVac)) s" }
        if let wh = d.batteryWh { s += ", \(Int(wh)) Wh" }
        if d.electricDraw > 0 { s += ", \(Int(d.electricDraw)) W" }
        return s
    }
}

func fmtMass(_ m: Double) -> String { m < 10 ? String(format: "%.1f", m) : String(Int(m.rounded())) }
