import Foundation

public final class ListRef { public var items: [Value]; public init(_ items: [Value]) { self.items = items } }

public enum DictKey: Hashable { case int(Int), str(String), bool(Bool), float(Double), tuple([DictKey]), none }

public final class DictRef {
    public var order: [DictKey] = []
    public var map: [DictKey: (key: Value, value: Value)] = [:]
    public init() {}
    public func set(_ k: DictKey, key: Value, _ v: Value) {
        if map[k] == nil { order.append(k) }
        map[k] = (key, v)
    }
}

public final class IterRef { var items: [Value]; var i = 0; init(_ items: [Value]) { self.items = items } }

/// Runtime values of the Python subset.
public enum Value {
    case none
    case bool(Bool)
    case int(Int)
    case float(Double)
    case str(String)
    case list(ListRef)
    case tuple([Value])
    case dict(DictRef)
    case function(Int)
    case builtin(String)
    case module(String)
    case iter(IterRef)

    public var typeName: String {
        switch self {
        case .none: "NoneType"; case .bool: "bool"; case .int: "int"; case .float: "float"; case .str: "str"
        case .list: "list"; case .tuple: "tuple"; case .dict: "dict"; case .function, .builtin: "function"
        case .module: "module"; case .iter: "iterator"
        }
    }

    public var truthy: Bool {
        switch self {
        case .none: false
        case let .bool(b): b
        case let .int(i): i != 0
        case let .float(d): d != 0
        case let .str(s): !s.isEmpty
        case let .list(l): !l.items.isEmpty
        case let .tuple(t): !t.isEmpty
        case let .dict(d): !d.order.isEmpty
        default: true
        }
    }

    public var asDouble: Double? {
        switch self {
        case let .int(i): Double(i)
        case let .float(d): d
        case let .bool(b): b ? 1 : 0
        default: nil
        }
    }

    public var repr: String {
        switch self {
        case .none: return "None"
        case let .bool(b): return b ? "True" : "False"
        case let .int(i): return String(i)
        case let .float(d):
            if d.isInfinite { return d > 0 ? "inf" : "-inf" }
            if d.isNaN { return "nan" }
            if d == d.rounded() && abs(d) < 1e16 { return String(format: "%.1f", d) }
            return String(d)
        case let .str(s): return s
        case let .list(l): return "[" + l.items.map(\.quoted).joined(separator: ", ") + "]"
        case let .tuple(t): return "(" + t.map(\.quoted).joined(separator: ", ") + (t.count == 1 ? ",)" : ")")
        case let .dict(d): return "{" + d.order.map { k in "\(d.map[k]!.key.quoted): \(d.map[k]!.value.quoted)" }.joined(separator: ", ") + "}"
        case .function, .builtin: return "<function>"
        case let .module(m): return "<module \(m)>"
        case .iter: return "<iterator>"
        }
    }

    var quoted: String { if case let .str(s) = self { return "'\(s)'" }; return repr }

    var dictKey: DictKey? {
        switch self {
        case let .int(i): .int(i)
        case let .str(s): .str(s)
        case let .bool(b): .int(b ? 1 : 0)
        case let .float(d): d == d.rounded() && abs(d) < 1e15 ? .int(Int(d)) : .float(d)
        case .none: DictKey.none
        case let .tuple(t):
            { let ks = t.compactMap(\.dictKey); return ks.count == t.count ? .tuple(ks) : nil }()
        default: nil
        }
    }

    public static func vec(_ x: Double, _ y: Double, _ z: Double) -> Value { .tuple([.float(x), .float(y), .float(z)]) }
}

func valuesEqual(_ a: Value, _ b: Value) -> Bool {
    switch (a, b) {
    case (.none, .none): return true
    case let (.str(x), .str(y)): return x == y
    case let (.list(x), .list(y)): return x === y || (x.items.count == y.items.count && zip(x.items, y.items).allSatisfy(valuesEqual))
    case let (.tuple(x), .tuple(y)): return x.count == y.count && zip(x, y).allSatisfy(valuesEqual)
    case let (.dict(x), .dict(y)): return x === y
    case let (.module(x), .module(y)): return x == y
    case let (.function(x), .function(y)): return x == y
    case let (.builtin(x), .builtin(y)): return x == y
    default:
        if let x = a.asDouble, let y = b.asDouble { return x == y }
        return false
    }
}

public struct VMFault: Error, Sendable, Hashable {
    public enum Kind: String, Sendable { case div0, index, key, budget, recursion, heap, type, name, value, sensor }
    public var kind: Kind
    public var message: String
    public var line: Int
    public init(_ kind: Kind, _ message: String, line: Int = 0) { self.kind = kind; self.message = message; self.line = line }
}
