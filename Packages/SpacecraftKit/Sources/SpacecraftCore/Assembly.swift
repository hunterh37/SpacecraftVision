import Foundation

/// One step of a guided build (specs/18): place one part (radial parts with their symmetry copies).
public struct AssemblyStep: Sendable, Hashable, Identifiable {
    public enum Node: Sendable, Hashable { case stack, radial(parent: UUID) }
    public var id: UUID { instance.id }
    public var instance: PartInstance
    public var node: Node
    public var tip: String
    public var concept: String

    public var partId: String { instance.partId }
}

/// Ordered build of a target craft: stack bottom to top, then radial parts by parent from the bottom up.
/// Applying the first k steps gives a partial craft whose stack bottom stays at y = 0, so every part's
/// target position in the finished craft is also its position while building.
public struct AssemblyPlan: Sendable, Hashable {
    public var target: CraftDesign
    public var steps: [AssemblyStep]

    public init(_ target: CraftDesign) {
        self.target = target
        var steps: [AssemblyStep] = []
        for p in target.stack.reversed() {
            steps.append(AssemblyStep(instance: p, node: .stack, tip: Self.tip(p, stack: true), concept: Self.concept(p.partId)))
        }
        for p in target.stack.reversed() {
            for r in target.radial where r.parentId == p.id {
                steps.append(AssemblyStep(instance: r, node: .radial(parent: p.id), tip: Self.tip(r, stack: false, on: p),
                                          concept: Self.concept(r.partId)))
            }
        }
        self.steps = steps
    }

    public var count: Int { steps.count }

    /// Craft with the first `k` steps applied.
    public func craft(upTo k: Int) -> CraftDesign {
        let done = Set(steps.prefix(max(0, min(k, steps.count))).map(\.id))
        var c = target
        c.stack = target.stack.filter { done.contains($0.id) }
        c.radial = target.radial.filter { done.contains($0.id) }
        return c
    }

    /// Steps done for a craft built so far (the longest prefix whose parts are all present).
    public func progress(of craft: CraftDesign) -> Int {
        let have = Set(craft.stack.map(\.id) + craft.radial.map(\.id))
        return steps.firstIndex { !have.contains($0.id) } ?? steps.count
    }

    /// Target placement of a step in the finished craft frame (stack bottom at y = 0, axis +y).
    /// Returns the part base height and, for radial parts, the mount radius and the angle of each copy.
    public func placement(of step: AssemblyStep) -> (y: Double, radius: Double, angles: [Double]) {
        let spans = target.stackSpans
        switch step.node {
        case .stack:
            let i = target.stack.firstIndex { $0.id == step.id } ?? 0
            return (spans[i].bottom, 0, [0])
        case let .radial(parent):
            let i = target.stack.firstIndex { $0.id == parent } ?? 0
            let span = spans[i], dia = target.stack[i].definition.diameter
            let n = max(1, step.instance.count)
            let y = step.partId == "fin-trapezoid" ? span.bottom : (span.bottom + span.top) / 2 - 0.1
            if n > 1 { return (y, dia / 2, (0..<n).map { Double($0) / Double(n) * 2 * .pi + .pi / 4 }) }
            // Single radial parts fan out around their parent in mount order.
            let slot = target.radial.filter { $0.parentId == parent && $0.count <= 1 }.firstIndex { $0.id == step.id } ?? 0
            return (y, dia / 2 + 0.05, [Double(slot) * 1.1 + 0.4])
        }
    }

    static func tip(_ p: PartInstance, stack: Bool, on parent: PartInstance? = nil) -> String {
        let name = p.definition.displayName
        if stack {
            switch p.definition.category {
            case .engine: return "Stand the \(name) on the pad. It is the bottom of the stack."
            default: return "Lower the \(name) onto the top of the stack."
            }
        }
        let on = parent?.definition.displayName ?? "the stack"
        if p.count > 1 { return "Fit \(p.count) x \(name) around the \(on)." }
        return "Mount the \(name) on the side of the \(on)."
    }

    static func concept(_ id: String) -> String {
        switch PartCatalog.part(id)?.category {
        case .engine?: return "Thrust pushes up through the stack from here."
        case .tank?: return "Propellant mass sets how long the engine burns."
        case .command?: return "The probe core runs your flight code."
        case .aero?: return id == "nose-cone" ? "A pointed nose cuts drag." : "Fins below the center of mass keep the nose forward."
        case .recovery?: return "The chute slows the fall to a safe landing speed."
        case .power?: return "The battery feeds the core and sensors."
        case .sensor?: return "Sensors give your code the state of the craft."
        case .structure?: return "Structure joins stages."
        case nil: return ""
        }
    }
}
