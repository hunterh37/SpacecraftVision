import Foundation
import Observation
import SpacecraftCore

/// Guided build state (specs/18). Every lock writes `AppModel.craft`, so the stat board, code preview
/// and range read the same craft as the Parts window.
@MainActor @Observable
final class AssemblyModel {
    enum Mode: String { case off, watch, manual }

    var plan: AssemblyPlan?
    var index = 0
    var mode: Mode = .off
    var playing = false
    var speed: Double = 1
    /// Wrong-part or out-of-range feedback for the tip card; cleared on the next lock.
    var warning: String?
    /// Bumped on every lock so the scene can flash the node.
    var locks = 0
    /// Manual mode: play the current step once, then hand control back.
    var showMe = false

    var active: Bool { mode != .off && plan != nil }
    var current: AssemblyStep? { plan.flatMap { index < $0.count ? $0.steps[index] : nil } }
    var done: Bool { plan.map { index >= $0.count } ?? false }

    func start(_ m: Mode, model: AppModel) {
        let target = model.referenceCraft()
        let p = AssemblyPlan(target)
        plan = p
        index = UserDefaults.standard.integer(forKey: key(model))
        if index > p.count || index < 0 { index = 0 }
        mode = m
        warning = nil
        playing = m == .watch
        model.workshopTabletop = false
        apply(model)
    }

    func stop() { mode = .off; playing = false; showMe = false; warning = nil }

    func lock(_ model: AppModel) {
        guard let p = plan, index < p.count else { return }
        index += 1
        locks += 1
        warning = nil
        model.partsAdded += 1
        apply(model)
        if index >= p.count { playing = false }
    }

    func back(_ model: AppModel) {
        guard index > 0 else { return }
        index -= 1
        warning = nil
        apply(model)
    }

    func restart(_ model: AppModel) { index = 0; warning = nil; apply(model) }

    func takeOver() { mode = .manual; playing = false }

    private func apply(_ model: AppModel) {
        guard let p = plan else { return }
        model.setAssembledCraft(p.craft(upTo: index))
        UserDefaults.standard.set(index >= p.count ? 0 : index, forKey: key(model))
    }

    private func key(_ model: AppModel) -> String { "assembly.\(model.mission.id).index" }
}
