import SwiftUI
import SpacecraftCore
import FlightSim
import FlightCode
import FlightRunner
import Curriculum
import LabUI

enum SpaceID: String { case workshop, range }
enum WindowID { static let main = "main", parts = "parts", code = "code", analysis = "analysis" }

enum FlightView: String, CaseIterable, Identifiable {
    case ground, chase, tabletop
    var id: String { rawValue }
    var label: String { switch self { case .ground: "Ground"; case .chase: "Chase"; case .tabletop: "Tabletop" } }
}

enum CompileStatus: Equatable {
    case idle, ok, error(CompileError)
}

@MainActor @Observable
final class AppModel {
    // Selection
    var mission: Mission = .m1 { didSet { if mission.id != oldValue.id { missionChanged() } } }
    var lesson: Lesson? = Lesson.all[0]
    var craft: CraftDesign = .rHop()
    var selectedStackPart: UUID?
    var workshopTabletop = false

    // Immersive
    var openSpace: SpaceID?
    var flightView: FlightView = .ground

    // Code
    var sources: [String: String] = [:]          // missionId -> source
    var compileStatus: CompileStatus = .idle
    var preview: FlightReport?
    var previewing = false
    private var previewTask: Task<Void, Never>?
    /// One block/Python/trace workspace per lesson, so edits survive switching lessons and windows.
    private var workspaces: [Int: CodeWorkspaceModel] = [:]

    // Flight
    let flight = FlightController()
    let walkthrough = WalkthroughModel()
    /// Set when the Analysis window first appears (walkthrough step 5).
    var analysisOpened = false

    // Walkthrough signals (Walkthrough/WalkthroughModel.swift predicates and demos)
    var homePath = NavigationPath()
    var openLesson: Lesson?
    var pseudocodeDemo = 0
    var codeOpened = false
    var missionPicked = false
    var partsAdded = 0
    var referenceLoads = 0

    /// Pops the main window to Home and pushes a mode screen.
    func showMode(_ m: GameMode) {
        homePath = NavigationPath()
        homePath.append(m)
    }

    func lessonReference(for m: Mission) -> String? { Lesson.all.first { $0.missionId == m.id }?.referenceCode }
    var lastReport: FlightReport?
    var lastCommands: [CommandRecord] = []
    var reports: [FlightReport] = []

    // Lesson progress
    var lessonStage: LessonStage = .concept
    var answers: [Int: Int] = [:]
    var pseudocodePassed: Set<Int> = []
    var completed: [Int: Int] = [:]   // lesson id -> stars

    init() {
        craft = .rHop()
        craft.payloadMass = mission.payloadMass
        schedulePreview()
    }

    var source: String {
        get { sources[mission.id] ?? starterCode(for: mission) }
        set { sources[mission.id] = newValue; schedulePreview() }
    }

    func starterCode(for m: Mission) -> String {
        Lesson.all.first { $0.missionId == m.id }?.starterCode ?? Lesson.all[0].starterCode
    }

    func workspace(for lesson: Lesson) -> CodeWorkspaceModel {
        if let w = workspaces[lesson.id] { return w }
        let missionId = lesson.missionId
        let w = CodeWorkspaceModel(lesson: lesson, initialSource: sources[missionId],
            sink: { [weak self] src in self?.sources[missionId] = src; self?.schedulePreview() },
            tracer: { [weak self] src, t in
                guard let self else { return .empty() }
                let craft = self.craft, mission = lesson.mission
                return await Task.detached(priority: .userInitiated) { FlightTracer.trace(source: src, craft: craft, mission: mission, atTime: t) }.value
            })
        workspaces[lesson.id] = w
        if w.usesBlocks { w.publish() }
        return w
    }

    /// The real rocket so far, from the live simulator, for the path graph's live marker.
    var liveFlight: FlightLive? {
        guard flight.phase != .idle, let s = flight.sim else { return nil }
        _ = flight.time      // observed, so the graph redraws every frame of a launch
        return FlightLive(samples: s.samples, running: flight.phase == .flying)
    }

    /// The first thing wrong with the player's code: a compile error, or the first runtime fault from the preview.
    var codeProblem: (line: Int, text: String)? {
        if case let .error(e) = compileStatus { return (e.line, e.message) }
        if let f = preview?.faults.first, f.hasPrefix("Line "), let colon = f.firstIndex(of: ":"), let line = Int(f[f.index(f.startIndex, offsetBy: 5)..<colon]) {
            return (line, String(f[f.index(colon, offsetBy: 2)...]))
        }
        return nil
    }

    func resetCode() { sources[mission.id] = starterCode(for: mission); schedulePreview() }

    func select(lesson l: Lesson) {
        lesson = l
        lessonStage = .concept
        mission = l.mission
    }

    private func missionChanged() {
        craft.payloadMass = mission.payloadMass
        if let f = mission.fixedFuelLoad { craft.setFuelLoad(f) }
        if mission.id == "M2" && craft.stats().propellantMass < 500 { craft.setFuelLoad(1.0) }
        schedulePreview()
    }

    var blockers: [LaunchBlocker] { mission.blockers(for: craft) }

    /// Reason adding a part would break a mission cap, or nil when it fits.
    func addBlock(_ id: String) -> String? {
        guard let def = PartCatalog.part(id) else { return "Unknown part" }
        let n = id == "fin-trapezoid" ? 4 : 1
        let s = craft.stats()
        let cost = s.cost + def.cost * n
        if cost > mission.budget { return "+\(def.cost * n) cr. Over budget by \(cost - mission.budget) cr" }
        if s.partCount + n > mission.partCap { return "Part cap \(mission.partCap) reached" }
        let load = def.mount == .stack ? (mission.fixedFuelLoad ?? 1) : 1
        let wet = s.wetMass + Double(n) * (def.dryMass + def.propellantMass * load)
        if wet > mission.massCap { return "+\(Int(wet - s.wetMass)) kg. Over mass cap by \(Int(wet - mission.massCap)) kg" }
        return nil
    }

    // MARK: Workshop edits

    func addPart(_ id: String) {
        guard let def = PartCatalog.part(id), addBlock(id) == nil else { return }
        partsAdded += 1
        if def.mount == .stack {
            var inst = PartInstance(partId: id, fuelLoad: mission.fixedFuelLoad ?? 1.0)
            if def.propellantMass == 0 { inst.fuelLoad = 1 }
            // Engines go to the bottom, nose cones to the top, the rest above the selected part or above the engine.
            if def.category == .engine { craft.stack.append(inst) }
            else if id == "nose-cone" { craft.stack.insert(inst, at: 0) }
            else if let sel = selectedStackPart, let i = craft.stack.firstIndex(where: { $0.id == sel }) { craft.stack.insert(inst, at: i + 1) }
            else if let ei = craft.stack.firstIndex(where: { $0.definition.category == .engine }) { craft.stack.insert(inst, at: ei) }
            else { craft.stack.append(inst) }
            selectedStackPart = inst.id
        } else {
            let parentId: UUID?
            if id == "fin-trapezoid" {
                parentId = craft.stack.last?.id
            } else {
                parentId = craft.stack.first { $0.definition.category == .command }?.id ?? selectedStackPart ?? craft.stack.first?.id
            }
            guard let parentId else { return }
            craft.radial.append(PartInstance(partId: id, parentId: parentId, count: id == "fin-trapezoid" ? 4 : 1))
        }
        schedulePreview()
    }

    func removeStack(_ id: UUID) {
        craft.stack.removeAll { $0.id == id }
        craft.radial.removeAll { $0.parentId == id }
        schedulePreview()
    }

    func removeRadial(_ id: UUID) { craft.radial.removeAll { $0.id == id }; schedulePreview() }

    func moveStack(_ id: UUID, by d: Int) {
        guard let i = craft.stack.firstIndex(where: { $0.id == id }) else { return }
        let j = i + d
        guard craft.stack.indices.contains(j) else { return }
        craft.stack.swapAt(i, j)
        schedulePreview()
    }

    func setFuel(_ id: UUID, _ load: Double) {
        guard mission.fixedFuelLoad == nil, let i = craft.stack.firstIndex(where: { $0.id == id }) else { return }
        craft.stack[i].fuelLoad = load
        schedulePreview()
    }

    func loadReferenceCraft() {
        referenceLoads += 1
        craft = mission.id == "M2" ? .rGates() : .rHop(fuelLoad: mission.fixedFuelLoad ?? 0.1)
        craft.payloadMass = mission.payloadMass
        schedulePreview()
    }

    func clearCraft() { craft.stack = []; craft.radial = []; schedulePreview() }

    // MARK: Preview

    func schedulePreview() {
        if flight.phase == .idle { flight.clearError() }
        previewTask?.cancel()
        let src = source, craft = craft, mission = mission
        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            previewing = true
            let rep = await Task.detached(priority: .userInitiated) {
                FlightPreview.run(source: src, craft: craft, mission: mission)
            }.value
            if Task.isCancelled { return }
            previewing = false
            preview = rep
            compileStatus = rep.compileError.map { .error($0) } ?? .ok
        }
    }

    // MARK: Flight

    func launch() {
        lastReport = nil
        flight.onFinish = { [weak self] report, cmds in
            guard let self else { return }
            lastReport = report
            lastCommands = cmds
            reports.append(report)
            if reports.count > 10 { reports.removeFirst() }
        }
        flight.launch(source: source, craft: craft, mission: mission)
    }

    // MARK: Lesson grading (specs/06)

    func grade(_ l: Lesson) -> (score: Int, stars: Int, tests: [HiddenTestResult])? {
        guard let rep = lastReport, rep.result.passed, mission.id == l.missionId else { return nil }
        let tests = l.hiddenTests(lastCommands)
        let testScore = tests.isEmpty ? 40.0 : 40.0 * Double(tests.filter(\.passed).count) / Double(tests.count)
        let fuel = 20 * min(1, l.mission.parFuel / max(rep.result.fuelUsed, 1))
        let apo = 20 * max(0, 1 - abs(rep.result.apogee - 1100) / 100)
        let ans = answers[l.id] == l.question.answer ? 20.0 : 0
        let score = Int((testScore + fuel + apo + ans).rounded())
        let stars = score >= 95 ? 3 : score >= 80 ? 2 : score >= 60 ? 1 : 0
        return (score, stars, tests)
    }
}
