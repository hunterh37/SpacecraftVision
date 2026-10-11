import SwiftUI
import SpacecraftCore

/// What a walkthrough step points at in the range.
enum WalkTarget: Equatable { case pad, ribbon, craft, hud }

/// One first-run step (notes/walkthrough/PLAN.md). Completion comes from app state; `manual` steps finish on Next.
struct WalkStep: Identifiable {
    let id: Int
    let title: String
    let body: String
    let more: String
    let target: WalkTarget
    let manual: Bool
    let isComplete: @MainActor (AppModel) -> Bool
}

/// Contextual tips shown once, the first time the feature is reachable.
enum TipID: String, CaseIterable {
    case hangar, code, failure, blocked

    var title: String {
        switch self {
        case .hangar: "HANGAR"
        case .code: "FLIGHT CODE"
        case .failure: "FAILED FLIGHT"
        case .blocked: "LAUNCH BLOCKED"
        }
    }

    var body: String {
        switch self {
        case .hangar: "Pinch a part in the Parts window. It joins the craft on the stand."
        case .code: "Edit update(dt). The range path re-predicts 0.3 s after each edit."
        case .failure: "The red sphere marks where the flight failed. Analysis shows why."
        case .blocked: "A red check blocks launch. Its fix button is beside it."
        }
    }

    var more: String {
        switch self {
        case .hangar: "The board beside the craft compares cost, mass and parts with the mission caps. Parts that would break a cap are greyed out with the reason."
        case .code: "setup() runs once before launch. update(dt) runs 50 times a second. Compile errors show the line number in red."
        case .failure: "Plots show altitude and vertical speed against time. Earlier runs appear as ghosts so changes can be compared."
        case .blocked: "Load reference craft restores the mission's known-good build. Open hangar edits the current one."
        }
    }
}

@MainActor @Observable
final class WalkthroughModel {
    static let doneKey = "walkthrough.v1.done"
    static let tipsKey = "walkthrough.v1.tips"

    private(set) var index: Int?
    private(set) var done: Bool
    private(set) var seenTips: Set<String>
    /// Tip currently shown in the range callout when no step is active.
    private(set) var rangeTip: TipID?
    var showMore = false
    /// Seconds on the current step; after 20 s the callout offers Skip in the accent colour.
    private(set) var stepTime = 0.0
    /// Increments on each completed step; the scene plays the success burst.
    private(set) var successCount = 0
    private var forcedStep: Int?

    let steps: [WalkStep] = [
        WalkStep(id: 0, title: "THE PAD", body: "The craft stands on the pad, 60 m ahead.",
                 more: "Ground view places you on the viewing platform. The white column marks the pad. The panel below stays with you in every view.",
                 target: .pad, manual: true, isComplete: { _ in false }),
        WalkStep(id: 1, title: "PREDICTED PATH", body: "The dots show where the code will fly the craft.",
                 more: "Blue dots are slow, orange are fast. A red sphere marks a predicted failure. The path updates 0.3 s after each code or part change.",
                 target: .ribbon, manual: true, isComplete: { _ in false }),
        WalkStep(id: 2, title: "PREFLIGHT", body: "Every check green clears the craft to launch.",
                 more: "Checks are command part, mass, parts and budget, plus a compiled script. A red check shows its fix: load the reference craft or open the hangar.",
                 target: .hud, manual: false,
                 isComplete: { m in m.blockers.isEmpty && m.compileStatus == .ok }),
        WalkStep(id: 3, title: "LAUNCH", body: "Pinch Launch on the panel.",
                 more: "The script's setup() runs once, then update(dt) runs every 0.02 s until touchdown, a failure or Abort.",
                 target: .craft, manual: false, isComplete: { m in m.flight.phase != .idle }),
        WalkStep(id: 4, title: "VIEWS", body: "Switch to Chase or Tabletop during the flight.",
                 more: "Chase follows the craft. Tabletop shrinks the course onto a table in front of you. 0.25x slows time near events.",
                 target: .hud, manual: false,
                 isComplete: { m in m.flightView != .ground || m.flight.phase == .finished }),
        WalkStep(id: 5, title: "DEBRIEF", body: "Open Analysis to see why the flight passed or failed.",
                 more: "Plots show altitude and vertical speed. Change the code or the craft, then launch again and compare the ghost runs.",
                 target: .hud, manual: false, isComplete: { m in m.analysisOpened }),
    ]

    init() {
        let d = UserDefaults.standard
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-walkthroughReset") {
            d.removeObject(forKey: Self.doneKey)
            d.removeObject(forKey: Self.tipsKey)
        }
        if let i = args.firstIndex(of: "-walkthroughStep"), i + 1 < args.count, let n = Int(args[i + 1]) {
            forcedStep = n
            d.removeObject(forKey: Self.doneKey)
        }
        done = d.bool(forKey: Self.doneKey)
        seenTips = Set(d.stringArray(forKey: Self.tipsKey) ?? [])
    }

    var current: WalkStep? { index.map { steps[$0] } }
    var active: Bool { index != nil }

    /// Called when the range opens.
    func startIfNeeded() {
        guard !done, index == nil else { return }
        index = min(forcedStep ?? 0, steps.count - 1)
        stepTime = 0
        showMore = false
    }

    func replay() {
        done = false
        seenTips = []
        UserDefaults.standard.set(false, forKey: Self.doneKey)
        UserDefaults.standard.set([String](), forKey: Self.tipsKey)
        index = nil
        rangeTip = nil
    }

    func next() {
        guard let i = index else { return }
        successCount += 1
        showMore = false
        stepTime = 0
        if i + 1 < steps.count { index = i + 1 } else { finish() }
    }

    func skip() { finish() }

    private func finish() {
        index = nil
        done = true
        UserDefaults.standard.set(true, forKey: Self.doneKey)
    }

    /// Per-frame evaluation from the range update loop.
    func tick(_ dt: Double, model: AppModel) {
        if let step = current {
            stepTime += dt
            if !step.manual && step.isComplete(model) { next() }
            return
        }
        // Contextual tips in the range, once each.
        if !model.blockers.isEmpty && model.flight.phase == .idle { offer(.blocked) }
        else if model.lastReport?.result.passed == false && model.flight.phase == .finished { offer(.failure) }
        else if let t = rangeTip, t == .blocked, model.blockers.isEmpty { dismissTip() }
    }

    private func offer(_ t: TipID) {
        guard rangeTip == nil, !seenTips.contains(t.rawValue) else { return }
        rangeTip = t
        showMore = false
    }

    func dismissTip() {
        if let t = rangeTip { markSeen(t) }
        rangeTip = nil
    }

    /// Window tips (hangar, code) shown inline; returns true while unseen.
    func shouldShow(_ t: TipID) -> Bool { !seenTips.contains(t.rawValue) }

    func markSeen(_ t: TipID) {
        seenTips.insert(t.rawValue)
        UserDefaults.standard.set(Array(seenTips), forKey: Self.tipsKey)
    }
}
