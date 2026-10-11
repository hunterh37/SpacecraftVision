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
            VStack(alignment: .leading, spacing: 18) {
                LabHeader("Parts", caption: "Hangar · \(model.mission.id)", tint: Brand.trajectory)
                TipBanner(tip: .hangar)
                budgetMeter.padding(18).labCard(corner: 22, tint: Brand.telemetry, aurora: 0.12)
                section("Rack: \(model.mission.id) parts") {
                    ForEach(model.mission.allowedParts, id: \.self) { id in
                        if let def = PartCatalog.part(id) {
                            let block = model.addBlock(id)
                            Button { model.addPart(id) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: icon(def.category)).font(.system(size: 17, weight: .semibold)).foregroundStyle(Brand.trajectory).frame(width: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(def.displayName).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Brand.ink)
                                        Text(block ?? detail(def)).font(.system(size: 12, weight: .medium)).foregroundStyle(block == nil ? Brand.dim : Brand.ignition)
                                    }
                                    Spacer()
                                    Text("\(def.cost) cr").font(Brand.label(12)).foregroundStyle(Brand.telemetry)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .labCard(corner: 16, tint: Brand.trajectory, aurora: 0.06)
                                .opacity(block == nil ? 1 : 0.5)
                            }
                            .buttonStyle(.plain).disabled(block != nil)
                        }
                    }
                }
                section("Stack, top to bottom") {
                    if model.craft.stack.isEmpty { Text("Empty. Add a probe core first.").font(.system(size: 14, weight: .medium)).foregroundStyle(Brand.dim) }
                    ForEach(model.craft.stack) { p in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(p.definition.displayName).font(.system(size: 16, weight: model.selectedStackPart == p.id ? .heavy : .semibold, design: .rounded))
                                    .foregroundStyle(model.selectedStackPart == p.id ? Brand.telemetry : Brand.ink)
                                Spacer()
                                Button { model.moveStack(p.id, by: -1) } label: { Image(systemName: "arrow.up") }
                                Button { model.moveStack(p.id, by: 1) } label: { Image(systemName: "arrow.down") }
                                Button(role: .destructive) { model.removeStack(p.id) } label: { Image(systemName: "trash") }
                            }
                            .buttonStyle(.borderless)
                            if p.definition.propellantMass > 0 {
                                HStack {
                                    Text("FUEL \(Int((p.fuelLoad * 100).rounded()))%").font(Brand.label(11)).foregroundStyle(Brand.dim)
                                    Slider(value: Binding(get: { p.fuelLoad }, set: { model.setFuel(p.id, ($0 * 20).rounded() / 20) }), in: 0...1, step: 0.05)
                                        .tint(Brand.telemetry).disabled(model.mission.fixedFuelLoad != nil)
                                }
                                if model.mission.fixedFuelLoad != nil {
                                    Text("Fuel load fixed by the mission.").font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.dim)
                                }
                            }
                            ForEach(model.craft.radial.filter { $0.parentId == p.id }) { r in
                                HStack {
                                    Text("+ \(r.definition.displayName)\(r.count > 1 ? " x\(r.count)" : "")").font(.system(size: 14, weight: .medium)).foregroundStyle(Brand.ink)
                                    Spacer()
                                    Button(role: .destructive) { model.removeRadial(r.id) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .labCard(corner: 16, tint: model.selectedStackPart == p.id ? Brand.telemetry : Brand.trajectory, aurora: 0.06)
                        .contentShape(Rectangle())
                        .onTapGesture { model.selectedStackPart = p.id }
                    }
                }
                section("Craft") {
                    Toggle("Tabletop scale", isOn: $model.workshopTabletop).font(.system(size: 15, weight: .semibold)).tint(Brand.telemetry)
                    HStack(spacing: 10) {
                        Button("Load reference craft") { model.loadReferenceCraft() }.buttonStyle(LabSecondaryButtonStyle(tint: Brand.telemetry))
                        Button("Clear craft", role: .destructive) { model.clearCraft() }.buttonStyle(LabSecondaryButtonStyle(tint: Lab.danger))
                    }
                }
            }
            .padding(24)
        }
        .labWindow(tint: Brand.trajectory, variant: .dusk)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) { Rectangle().fill(Brand.trajectory).frame(width: 22, height: 3).clipShape(Capsule()); Text(title.uppercased()).font(Brand.label(11)).tracking(2.2).foregroundStyle(Brand.trajectory) }
            content()
        }
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
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
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
