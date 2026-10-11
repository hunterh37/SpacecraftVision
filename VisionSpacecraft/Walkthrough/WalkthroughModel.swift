import SwiftUI
import SpacecraftCore
import Curriculum

/// What a range step points at with spatial indicators.
enum WalkTarget: Equatable { case pad, ribbon, craft, hud }

/// One guided tour per game mode plus the range tour (notes/walkthrough/PLAN.md).
enum TourID: String, CaseIterable, Identifiable {
    case learn, missions, workshop, range
    var id: String { rawValue }
    var title: String {
        switch self { case .learn: "Learn"; case .missions: "Missions"; case .workshop: "Workshop"; case .range: "Launch range" }
    }
}

/// Environment actions a step demo needs to perform the real action.
@MainActor
struct TourActions {
    let model: AppModel
    let openWindow: OpenWindowAction
    let switcher: SpaceSwitcher
}

/// One step. `isComplete == nil` means the step finishes on Next. `demo` performs the real action
/// the player was asked to do, used by Show me and by autoplay.
struct WalkStep: Identifiable {
    let id: Int
    let title: String
    let body: String
    let more: String
    var target: WalkTarget? = nil
    var isComplete: (@MainActor (AppModel) -> Bool)? = nil
    var demo: @MainActor (TourActions) async -> Void = { _ in }
    var manual: Bool { isComplete == nil }
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
        case .failure: "The red sphere marks where it failed."
        case .blocked: "Launch blocked. Pinch Fix craft."
        }
    }

    var more: String {
        switch self {
        case .hangar: "The board beside the craft compares cost, mass and parts with the mission caps. Parts that would break a cap are greyed out with the reason."
        case .code: "setup() runs once before launch. update(dt) runs 50 times a second. Compile errors show the line number in red."
        case .failure: "Plots show altitude and vertical speed against time. Earlier runs appear as ghosts so changes can be compared."
        case .blocked: "Fix craft restores the known-good build. Long-press it to open the hangar instead."
        }
    }
}

@MainActor @Observable
final class WalkthroughModel {
    static let enabledKey = "walkthrough.enabled"
    static let doneKey = "walkthrough.v2.done"
    static let tipsKey = "walkthrough.v1.tips"

    private(set) var tour: TourID?
    private(set) var index: Int?
    private(set) var done: Set<String>
    private(set) var seenTips: Set<String>
    /// Guided tours start automatically when true. Settings toggle.
    var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: Self.enabledKey); if !enabled { end() } } }
    /// True while steps play themselves (Play rest, Watch full demo).
    private(set) var autoplaying = false
    /// True while a single step's demo runs.
    private(set) var demoing = false
    /// Defers overlapping Workshop tour prompts while Guided Workshop is active. Does not change `enabled` or mark tours done.
    private(set) var suspendedForTaskGuide = false
    private var suspendedTour: TourID?
    private var suspendedIndex: Int?
    private(set) var rangeTip: TipID?
    var showMore = false
    private var stepStart = Date()
    /// Increments on each completed step; the range plays the success burst.
    private(set) var successCount = 0
    private var pending: [TourID] = []
    private var forcedStep: Int?
    private var playTask: Task<Void, Never>?

    var stepTime: Double { Date().timeIntervalSince(stepStart) }

    init() {
        let d = UserDefaults.standard
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-walkthroughReset") {
            d.removeObject(forKey: Self.doneKey)
            d.removeObject(forKey: Self.tipsKey)
            d.removeObject(forKey: Self.enabledKey)
        }
        if let i = args.firstIndex(of: "-walkthroughStep"), i + 1 < args.count, let n = Int(args[i + 1]) {
            forcedStep = n
            d.removeObject(forKey: Self.doneKey)
        }
        enabled = d.object(forKey: Self.enabledKey) as? Bool ?? true
        done = Set(d.stringArray(forKey: Self.doneKey) ?? [])
        seenTips = Set(d.stringArray(forKey: Self.tipsKey) ?? [])
    }

    var steps: [WalkStep] { tour.map(Self.steps(for:)) ?? [] }
    var current: WalkStep? { index.flatMap { i in steps.indices.contains(i) ? steps[i] : nil } }
    var active: Bool { index != nil }
    func isDone(_ t: TourID) -> Bool { done.contains(t.rawValue) }

    // MARK: Lifecycle

    /// Called when a mode screen or the range appears.
    func startIfNeeded(_ t: TourID) {
        guard enabled, !suspendedForTaskGuide, !isDone(t), tour != t, !pending.contains(t) else { return }
        if tour != nil { pending.append(t); return }
        begin(t, at: forcedStep ?? 0)
        forcedStep = nil
    }

    /// Hides the active tour card without marking tours complete or changing the global preference.
    func suspendForTaskGuide() {
        guard !suspendedForTaskGuide else { return }
        suspendedForTaskGuide = true
        suspendedTour = tour
        suspendedIndex = index
        stopAutoplay()
        rangeTip = nil
        end(markDone: false)
    }

    /// Restores a tour that was active when Guided Workshop started, only in an appropriate context.
    /// Callers should avoid restoring a Workshop tour while the user is in Launch Range or Space.
    func resumeAfterTaskGuide(allowWorkshopRestore: Bool = true) {
        guard suspendedForTaskGuide else { return }
        let savedTour = suspendedTour
        let savedIndex = suspendedIndex
        suspendedForTaskGuide = false
        suspendedTour = nil
        suspendedIndex = nil
        guard enabled, let t = savedTour, let i = savedIndex, !isDone(t) else { return }
        if t == .workshop, !allowWorkshopRestore { return }
        begin(t, at: i)
    }

    /// Range entry point kept for RangeImmersiveView.
    func startIfNeeded() { startIfNeeded(.range) }

    func begin(_ t: TourID, at step: Int = 0) {
        tour = t
        index = min(step, Self.steps(for: t).count - 1)
        stepStart = Date()
        showMore = false
    }

    /// Replays one tour now, or all tours on their next screen when `t` is nil.
    func replay(_ t: TourID? = nil) {
        stopAutoplay()
        rangeTip = nil
        if let t {
            done.remove(t.rawValue)
            persistDone()
            end(markDone: false)
            begin(t)
        } else {
            done = []
            seenTips = []
            persistDone()
            UserDefaults.standard.set([String](), forKey: Self.tipsKey)
            end(markDone: false)
        }
    }

    func next() {
        guard let i = index, let t = tour else { return }
        successCount += 1
        showMore = false
        stepStart = Date()
        if i + 1 < Self.steps(for: t).count { index = i + 1 } else { finishTour() }
    }

    /// Ends the current tour and marks it done.
    func skip() { stopAutoplay(); finishTour() }

    private func finishTour() {
        if let t = tour { done.insert(t.rawValue); persistDone() }
        end(markDone: false)
        while let n = pending.first {
            pending.removeFirst()
            if !isDone(n) { begin(n); break }
        }
    }

    private func end(markDone: Bool = false) {
        if markDone, let t = tour { done.insert(t.rawValue); persistDone() }
        tour = nil
        index = nil
        if !enabled { pending = [] }
    }

    private func persistDone() { UserDefaults.standard.set(Array(done), forKey: Self.doneKey) }

    // MARK: Demo

    /// Performs the current step's real action, then advances.
    func showMe(_ a: TourActions) {
        guard let step = current, !demoing else { return }
        playTask = Task { await runDemo(step, a); if !autoplaying { advanceIfStill(step) } }
    }

    /// Plays the remaining steps of the current tour, and every queued tour, on their own.
    func playRest(_ a: TourActions) {
        guard tour != nil else { return }
        autoplaying = true
        playTask?.cancel()
        playTask = Task { await loop(a) }
    }

    /// Plays the whole app: Learn, Missions (into the range), then Workshop.
    func watchFullDemo(_ a: TourActions) {
        stopAutoplay()
        end()
        pending = [.missions, .range, .workshop]
        a.model.homePath = NavigationPath()
        a.model.homePath.append(GameMode.learn)
        begin(.learn)
        playRest(a)
    }

    func stopAutoplay() {
        autoplaying = false
        demoing = false
        playTask?.cancel()
        playTask = nil
    }

    private func loop(_ a: TourActions) async {
        while autoplaying, let step = current, !Task.isCancelled {
            // Let the card be read before the action plays.
            try? await Task.sleep(for: .seconds(2.8))
            guard autoplaying, current?.id == step.id, !Task.isCancelled else { break }
            await runDemo(step, a)
            try? await Task.sleep(for: .seconds(1.2))
            if Task.isCancelled { break }
            advanceIfStill(step)
            if current == nil { break }
        }
        autoplaying = false
    }

    private func runDemo(_ step: WalkStep, _ a: TourActions) async {
        demoing = true
        await step.demo(a)
        // Wait for the action to land (window opened, flight finished) up to 20 s.
        if let done = step.isComplete {
            let t0 = Date()
            while !done(a.model), Date().timeIntervalSince(t0) < 20, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
        demoing = false
    }

    private func advanceIfStill(_ step: WalkStep) {
        guard current?.id == step.id, let t = tour, Self.steps(for: t).contains(where: { $0.id == step.id }) else { return }
        next()
    }

    // MARK: Tick

    /// Evaluates completion predicates. Called by the range update loop and the main window's ticker.
    func tick(_ dt: Double = 0, model: AppModel) {
        if let step = current {
            if !demoing, let c = step.isComplete, c(model) { next() }
            return
        }
        guard model.openSpace == .range else { return }
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

    func shouldShow(_ t: TipID) -> Bool { enabled && !suspendedForTaskGuide && !seenTips.contains(t.rawValue) }

    func markSeen(_ t: TipID) {
        seenTips.insert(t.rawValue)
        UserDefaults.standard.set(Array(seenTips), forKey: Self.tipsKey)
    }
}

// MARK: Steps

extension WalkthroughModel {
    static func steps(for t: TourID) -> [WalkStep] {
        switch t {
        case .learn: learnSteps
        case .missions: missionSteps
        case .workshop: workshopSteps
        case .range: rangeSteps
        }
    }

    static let learnSteps: [WalkStep] = [
        WalkStep(id: 0, title: "PICK A LESSON", body: "Pinch lesson 00 to open it.",
                 more: "Each lesson teaches one flight-code idea and ends with a real flight graded by hidden tests. Stars show the best score.",
                 isComplete: { $0.openLesson != nil },
                 demo: { a in
                     let l = Lesson.all[0]
                     a.model.select(lesson: l)
                     a.model.homePath.append(l)
                 }),
        WalkStep(id: 1, title: "CONCEPT", body: "Read the narration cards, then pinch Next.",
                 more: "Next line steps through the idea. The stage bar on top jumps to any stage.",
                 isComplete: { $0.openLesson != nil && $0.lessonStage.rawValue > LessonStage.concept.rawValue },
                 demo: { a in a.model.lessonStage = .pseudocode }),
        WalkStep(id: 2, title: "PSEUDOCODE", body: "Tap the blocks in order, then Check.",
                 more: "One block does not belong. Tap a placed block to send it back to the pool.",
                 isComplete: { m in m.openLesson.map { m.pseudocodePassed.contains($0.id) } ?? false },
                 demo: { a in
                     a.model.lessonStage = .pseudocode
                     try? await Task.sleep(for: .milliseconds(400))
                     a.model.pseudocodeDemo += 1
                 }),
        WalkStep(id: 3, title: "IMPLEMENT", body: "Open the code editor and fill the TODOs.",
                 more: "The starter keeps the pseudocode as comments. The status line shows the compile result and the predicted flight.",
                 isComplete: { $0.codeOpened },
                 demo: { a in
                     a.model.lessonStage = .implement
                     a.openWindow(id: WindowID.code)
                     try? await Task.sleep(for: .seconds(1.5))
                     if let l = a.model.openLesson { a.model.source = l.referenceCode }
                 }),
        WalkStep(id: 4, title: "RUN", body: "Pinch Launch in range to fly your code.",
                 more: "The range opens around you and the flight starts. The result card appears when the craft lands or fails.",
                 isComplete: { $0.lastReport != nil && $0.flight.phase == .finished },
                 demo: { a in
                     a.model.lessonStage = .run
                     await a.switcher.show(.range)
                     a.model.flight.timeScale = 4
                     a.model.launch()
                 }),
        WalkStep(id: 5, title: "ANALYZE", body: "Answer the question from the plots.",
                 more: "Score is hidden tests, fuel, apogee accuracy and the answer. Complete lesson saves the stars.",
                 isComplete: { m in m.openLesson.map { m.answers[$0.id] != nil } ?? false },
                 demo: { a in
                     a.model.lessonStage = .analyze
                     try? await Task.sleep(for: .seconds(1))
                     if let l = a.model.openLesson { a.model.answers[l.id] = l.question.answer }
                     try? await Task.sleep(for: .seconds(1.5))
                     await a.switcher.close()
                 }),
    ]

    static let missionSteps: [WalkStep] = [
        WalkStep(id: 0, title: "MISSION LIST", body: "Each row is a brief: goal, mass, parts, budget.",
                 more: "The caps are hard limits. The range preflight blocks launch until the craft fits all of them.",
                 demo: { a in a.model.showMode(.missions) }),
        WalkStep(id: 1, title: "SELECT", body: "Pinch a mission row to select it.",
                 more: "The selected mission is outlined. The hangar and the code editor follow the selection.",
                 isComplete: { $0.missionPicked },
                 demo: { a in a.model.mission = .m1; a.model.missionPicked = true }),
        WalkStep(id: 2, title: "CODE FIRST", body: "Open Code to see the script that flies it.",
                 more: "Code in the bottom bar opens the editor for the selected mission. Analysis opens the plots window.",
                 isComplete: { $0.codeOpened },
                 demo: { a in
                     a.openWindow(id: WindowID.code)
                     try? await Task.sleep(for: .seconds(1))
                     a.model.source = a.model.lessonReference(for: a.model.mission) ?? a.model.source
                 }),
        WalkStep(id: 3, title: "FLY", body: "Pinch Fly to open the launch range.",
                 more: "The range tour continues there: pad, predicted path, preflight, launch, views and debrief.",
                 isComplete: { $0.openSpace == .range },
                 demo: { a in await a.switcher.show(.range) }),
    ]

    static let workshopSteps: [WalkStep] = [
        WalkStep(id: 0, title: "ENTER HANGAR", body: "Pinch Enter. The craft stands at life size.",
                 more: "The Parts window opens beside you. The stat board next to the craft tracks every cap.",
                 isComplete: { $0.openSpace == .workshop },
                 demo: { a in
                     a.model.showMode(.workshop)
                     await a.switcher.show(.workshop)
                     a.openWindow(id: WindowID.parts)
                 }),
        WalkStep(id: 1, title: "ADD A PART", body: "Pinch a part in the Parts window.",
                 more: "Engines go to the bottom, nose cones to the top, the rest above the selected part. Greyed parts would break a cap.",
                 isComplete: { $0.partsAdded > 0 },
                 demo: { a in
                     let m = a.model
                     if let id = m.mission.allowedParts.first(where: { m.addBlock($0) == nil }) { m.addPart(id) }
                     else { m.clearCraft(); m.loadReferenceCraft(); m.partsAdded += 1 }
                 }),
        WalkStep(id: 2, title: "ARRANGE", body: "Use the arrows to move a part up or down the stack.",
                 more: "Tap a stack row to select it. New parts insert above the selection. Trash removes a part and its radial parts.",
                 demo: { a in
                     if let p = a.model.selectedStackPart { a.model.moveStack(p, by: -1) }
                 }),
        WalkStep(id: 3, title: "TABLETOP", body: "Turn on Tabletop scale to see the whole craft.",
                 more: "Tabletop shrinks the craft onto a stand in front of you. Turn it off to walk around it at life size.",
                 isComplete: { $0.workshopTabletop },
                 demo: { a in a.model.workshopTabletop = true }),
        WalkStep(id: 4, title: "REFERENCE CRAFT", body: "Load reference craft restores a known-good build.",
                 more: "Use it when a build breaks a cap or will not fly. Clear craft empties the stack.",
                 isComplete: { $0.referenceLoads > 0 },
                 demo: { a in
                     a.model.workshopTabletop = false
                     a.model.loadReferenceCraft()
                 }),
        WalkStep(id: 5, title: "TO THE RANGE", body: "Pinch Launch on the Range row to fly this craft.",
                 more: "The craft carries over. The range preflight checks it against the mission caps.",
                 isComplete: { $0.openSpace == .range },
                 demo: { a in await a.switcher.show(.range) }),
    ]

    static let rangeSteps: [WalkStep] = [
        WalkStep(id: 0, title: "THE PAD", body: "Your craft. 60 m ahead.",
                 more: "Ground view places you on the viewing platform. The white column marks the pad. The panel below stays with you in every view.",
                 target: .pad),
        WalkStep(id: 1, title: "PREDICTED PATH", body: "Dots show where your code will fly.",
                 more: "Blue dots are slow, orange are fast. A red sphere marks a predicted failure. The path updates 0.3 s after each code or part change.",
                 target: .ribbon),
        WalkStep(id: 2, title: "PREFLIGHT", body: "Pinch the panel's button until it reads Launch.",
                 more: "Fix craft loads the known-good build. Open code shows a compile error. Tap the status line for every check.",
                 target: .hud,
                 isComplete: { m in m.blockers.isEmpty && m.compileStatus == .ok },
                 demo: { a in
                     if !a.model.blockers.isEmpty { a.model.loadReferenceCraft() }
                     if case .error = a.model.compileStatus { a.model.resetCode() }
                 }),
        WalkStep(id: 3, title: "LAUNCH", body: "Pinch Launch.",
                 more: "The script's setup() runs once, then update(dt) runs every 0.02 s until touchdown, a failure or Abort.",
                 target: .craft, isComplete: { $0.flight.phase != .idle },
                 demo: { a in
                     if a.model.blockers.isEmpty { a.model.launch() }
                 }),
        WalkStep(id: 4, title: "VIEWS", body: "Pinch the view button to follow the craft.",
                 more: "It cycles Ground, Chase and Tabletop. The tortoise slows time near events. Tap the numbers for more telemetry.",
                 target: .hud,
                 isComplete: { m in m.flightView != .ground || m.flight.phase == .finished },
                 demo: { a in
                     a.model.flightView = .chase
                     try? await Task.sleep(for: .seconds(3))
                     a.model.flight.timeScale = 4
                 }),
        WalkStep(id: 5, title: "DEBRIEF", body: "Pinch Debrief to see why.",
                 more: "Plots show altitude and vertical speed. Then Fly again: earlier runs appear as ghosts.",
                 target: .hud, isComplete: { $0.analysisOpened },
                 demo: { a in
                     while a.model.flight.phase == .flying || a.model.flight.phase == .paused {
                         try? await Task.sleep(for: .milliseconds(250))
                     }
                     a.model.flightView = .ground
                     a.openWindow(id: WindowID.analysis)
                 }),
    ]
}
