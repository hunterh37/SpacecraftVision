import Foundation

/// Scratch-style block colour families. The UI maps each to a hue.
public enum BlockCategory: String, Codable, Sendable, CaseIterable {
    case motion, sensing, operators, control, variables, event
}

/// One piece of a block's sentence.
public enum BlockPart: Codable, Sendable, Hashable {
    case text(String)
    /// A named variable, drawn as an orange pill.
    case variable(String)
    /// A computed value described in words, drawn as a white pill.
    case reporter(String)
    /// An editable number bound to a knob key of the program.
    case input(String)
}

/// A visual statement. `firstLine...lastLine` index into the owning spec's `lines`, so the UI can light a block
/// when its line runs, and the trace can name the block a line came from.
public struct BlockNode: Codable, Sendable, Hashable {
    public var category: BlockCategory
    public var parts: [BlockPart]
    public var kids: [BlockNode]
    public var firstLine: Int
    public var lastLine: Int
    public init(_ category: BlockCategory, _ parts: [BlockPart], lines: ClosedRange<Int>, kids: [BlockNode] = []) {
        self.category = category; self.parts = parts; self.kids = kids; firstLine = lines.lowerBound; lastLine = lines.upperBound
    }
    public var isC: Bool { !kids.isEmpty }
}

/// A number the player can tune. `value` is the starting value, `reference` the value the reference solution uses.
public struct BlockKnob: Codable, Sendable, Hashable, Identifiable {
    public var key: String
    public var label: String
    public var value: Double
    public var reference: Double
    public var min: Double
    public var max: Double
    public var step: Double
    public var unit: String
    public var id: String { key }
    public init(_ key: String, _ label: String, start: Double, reference: Double, range: ClosedRange<Double>, step: Double, unit: String = "") {
        self.key = key; self.label = label; value = start; self.reference = reference
        min = range.lowerBound; max = range.upperBound; self.step = step; self.unit = unit
    }
}

public struct BlockSpec: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var summary: String
    public var category: BlockCategory
    /// A block that does not belong in the algorithm; stage 2 expects the player to leave it out.
    public var isDistractor: Bool
    /// Python statements this block produces, relative indent kept, no scaffold indent.
    public var lines: [String]
    public var nodes: [BlockNode]
    public init(id: String, name: String, summary: String, category: BlockCategory, distractor: Bool = false, lines: [String], nodes: [BlockNode]) {
        self.id = id; self.name = name; self.summary = summary; self.category = category; isDistractor = distractor
        self.lines = lines; self.nodes = nodes
    }
}

public struct LineOrigin: Sendable, Hashable, Codable {
    public var blockID: String
    public var line: Int
}

public struct ComposedSource: Sendable, Hashable {
    public var source: String
    /// One entry per source line: which block line produced it, or nil for scaffold lines.
    public var origins: [LineOrigin?]
}

/// A lesson's block palette plus the scaffold the placed blocks are composed into.
public struct BlockProgram: Codable, Sendable, Hashable {
    /// Lesson source with `{{BODY}}` where the blocks go and `{{KEY}}` for each knob.
    public var scaffold: String
    public var specs: [BlockSpec]
    public var knobs: [BlockKnob]
    /// Block ids in the order that solves the lesson (distractors excluded).
    public var solution: [String]

    public func spec(_ id: String) -> BlockSpec? { specs.first { $0.id == id } }
    public var startingValues: [String: Double] { Dictionary(uniqueKeysWithValues: knobs.map { ($0.key, $0.value) }) }
    public var referenceValues: [String: Double] { Dictionary(uniqueKeysWithValues: knobs.map { ($0.key, $0.reference) }) }

    public static func pythonNumber(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 1e9 ? String(format: "%.1f", v) : String(v)
    }

    public func compose(order: [String], values: [String: Double]) -> ComposedSource {
        var out: [String] = [], origins: [LineOrigin?] = []
        func fill(_ s: String) -> String {
            var r = s
            for k in knobs { r = r.replacingOccurrences(of: "{{\(k.key)}}", with: Self.pythonNumber(values[k.key] ?? k.value)) }
            return r
        }
        for raw in scaffold.components(separatedBy: "\n") {
            guard raw.trimmingCharacters(in: .whitespaces) == "{{BODY}}" else { out.append(fill(raw)); origins.append(nil); continue }
            let indent = String(raw.prefix { $0 == " " })
            let placed = order.compactMap(spec)
            if placed.isEmpty { out.append(indent + "pass"); origins.append(nil) }
            for s in placed { for (i, l) in s.lines.enumerated() { out.append(indent + l); origins.append(LineOrigin(blockID: s.id, line: i)) } }
        }
        return ComposedSource(source: out.joined(separator: "\n"), origins: origins)
    }
}
