import SwiftUI
import SpacecraftCore

/// Part palette (specs/02): mission-allowed parts, the current stack top to bottom with radial parts,
/// fuel load per tank, reorder and remove.
struct PartPickerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    TipBanner(tip: .hangar)
                    budgetMeter
                }
                Section("Rack: \(model.mission.id) parts") {
                    ForEach(model.mission.allowedParts, id: \.self) { id in
                        if let def = PartCatalog.part(id) {
                            let block = model.addBlock(id)
                            Button { model.addPart(id) } label: {
                                HStack {
                                    Image(systemName: icon(def.category)).frame(width: 28)
                                    VStack(alignment: .leading) {
                                        Text(def.displayName)
                                        Text(block ?? detail(def)).font(.caption)
                                            .foregroundStyle(block == nil ? Color.secondary : Brand.ignition)
                                    }
                                    Spacer()
                                    Text("\(def.cost) cr").font(.caption.monospacedDigit())
                                }
                            }
                            .disabled(block != nil)
                        }
                    }
                }
                Section("Stack, top to bottom") {
                    if model.craft.stack.isEmpty { Text("Empty. Add a probe core first.").foregroundStyle(.secondary) }
                    ForEach(model.craft.stack) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(p.definition.displayName).fontWeight(model.selectedStackPart == p.id ? .bold : .regular)
                                Spacer()
                                Button { model.moveStack(p.id, by: -1) } label: { Image(systemName: "arrow.up") }
                                Button { model.moveStack(p.id, by: 1) } label: { Image(systemName: "arrow.down") }
                                Button(role: .destructive) { model.removeStack(p.id) } label: { Image(systemName: "trash") }
                            }
                            .buttonStyle(.borderless)
                            if p.definition.propellantMass > 0 {
                                HStack {
                                    Text("Fuel \(Int((p.fuelLoad * 100).rounded()))%").font(.caption.monospacedDigit())
                                    Slider(value: Binding(get: { p.fuelLoad }, set: { model.setFuel(p.id, ($0 * 20).rounded() / 20) }),
                                           in: 0...1, step: 0.05)
                                        .disabled(model.mission.fixedFuelLoad != nil)
                                }
                                if model.mission.fixedFuelLoad != nil {
                                    Text("Fuel load fixed by the mission.").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            ForEach(model.craft.radial.filter { $0.parentId == p.id }) { r in
                                HStack {
                                    Text("  + \(r.definition.displayName)\(r.count > 1 ? " x\(r.count)" : "")").font(.callout)
                                    Spacer()
                                    Button(role: .destructive) { model.removeRadial(r.id) } label: { Image(systemName: "minus.circle") }
                                        .buttonStyle(.borderless)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { model.selectedStackPart = p.id }
                    }
                }
                Section {
                    Toggle("Tabletop scale", isOn: $model.workshopTabletop)
                    Button("Load reference craft") { model.loadReferenceCraft() }
                    Button("Clear craft", role: .destructive) { model.clearCraft() }
                }
            }
            .navigationTitle("Parts")
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
