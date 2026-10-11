import Foundation

/// Host calls for `craft.*` (the craft API of specs/05).
public protocol VMHost: AnyObject {
    func craftCall(_ name: String, _ args: [Value]) throws -> Value
}

/// One stop of the execution trace: a source line is about to run, with the variables visible right now.
public struct TraceStop {
    public let function: String
    public let line: Int
    public let variables: [(name: String, value: Value)]
}

/// Stack bytecode interpreter with an instruction budget per call, recursion depth 64 and a heap cap.
public final class VM {
    public static let tickBudget = 100_000
    public static let setupBudget = 5_000_000
    static let maxDepth = 64
    static let heapCap = 1_000_000 / 16      // values, about 1 MB

    public let program: Program
    public weak var host: VMHost?
    var globals: [Value?]
    var stack: [Value] = []
    struct Frame { let code: Code; var pc: Int; var locals: [Value?]; let base: Int }
    var frames: [Frame] = []
    public private(set) var currentLine = 0
    public private(set) var instructionsUsed = 0
    /// Called each time execution reaches a new source line. Nil (the default) costs one optional check per instruction.
    public var traceHook: ((TraceStop) -> Void)?
    private var traceFrames = -1, traceLine = -1, tracePC = -1
    var budget = 0
    var heapUsed = 0

    public init(program: Program, host: VMHost?) {
        self.program = program; self.host = host
        globals = Array(repeating: nil, count: program.globals.count)
    }

    /// Run module-level code once.
    public func load() throws(VMFault) {
        _ = try run(program.module, args: [], budget: Self.setupBudget)
    }

    public func hasFunction(_ name: String) -> Bool {
        if let i = program.globalIndex[name], i < globals.count, case .function = globals[i] { return true }
        return false
    }

    /// Call a module-level function by name. Missing functions return None.
    @discardableResult
    public func call(_ name: String, _ args: [Value], budget: Int = VM.tickBudget) throws(VMFault) -> Value {
        guard let gi = program.globalIndex[name], gi < globals.count, case let .function(fi)? = globals[gi] else { return .none }
        let code = program.functions[fi]
        guard args.count == code.params else {
            throw VMFault(.type, "\(name)() takes \(code.params) arguments, got \(args.count)", line: currentLine)
        }
        return try run(code, args: args, budget: budget)
    }

    func run(_ code: Code, args: [Value], budget: Int) throws(VMFault) -> Value {
        stack.removeAll(keepingCapacity: true)
        frames.removeAll(keepingCapacity: true)
        self.budget = budget
        instructionsUsed = 0
        heapUsed = 0
        var locals = [Value?](repeating: nil, count: max(code.nlocals, args.count))
        for (i, a) in args.enumerated() { locals[i] = a }
        frames.append(Frame(code: code, pc: 0, locals: locals, base: 0))
        return try loop()
    }

    /// Fire the trace hook on entering a new line, a new frame, or after a backward jump (a loop turning over).
    private func traceStep(_ fi: Int, _ code: Code, _ pc: Int) {
        let line = code.lines[pc]
        guard line > 0 else { return }
        defer { traceFrames = frames.count; traceLine = line; tracePC = pc }
        guard frames.count != traceFrames || line != traceLine || pc <= tracePC else { return }
        var vars: [(name: String, value: Value)] = []
        for (i, n) in code.localNames.enumerated() where i < frames[fi].locals.count {
            if let v = frames[fi].locals[i] { vars.append((n, v)) }
        }
        for (i, n) in program.globals.enumerated() where i < globals.count {
            guard let v = globals[i] else { continue }
            switch v {
            case .function, .builtin, .module, .iter: continue
            default: vars.append((n, v))
            }
        }
        traceHook?(TraceStop(function: code.name, line: line, variables: vars))
    }

    func fault(_ k: VMFault.Kind, _ m: String) -> VMFault { VMFault(k, m, line: currentLine) }

    @inline(__always) func pop() -> Value { stack.removeLast() }

    func loop() throws(VMFault) -> Value {
        while true {
            let fi = frames.count - 1
            let code = frames[fi].code
            let pc = frames[fi].pc
            let op = code.ops[pc]
            currentLine = code.lines[pc]
            if traceHook != nil { traceStep(fi, code, pc) }
            frames[fi].pc = pc + 1
            instructionsUsed += 1
            if instructionsUsed > budget { throw fault(.budget, "Tick used more than \(budget.formatted()) instructions") }
            switch op {
            case let .const(i): stack.append(program.consts[i])
            case let .loadLocal(i):
                guard let v = frames[fi].locals[i] else {
                    throw fault(.name, "Local variable used before assignment")
                }
                stack.append(v)
            case let .storeLocal(i): frames[fi].locals[i] = pop()
            case let .loadGlobal(i):
                if i < globals.count, let v = globals[i] { stack.append(v) } else {
                    let n = program.globals[i]
                    if Builtins.names.contains(n) { stack.append(.builtin(n)) } else {
                        throw fault(.name, "Name '\(n)' is not defined")
                    }
                }
            case let .storeGlobal(i):
                if i >= globals.count { globals += Array(repeating: nil, count: i - globals.count + 1) }
                globals[i] = pop()
            case let .binary(b):
                let r = pop(), l = pop()
                stack.append(try binary(b, l, r))
            case .neg:
                switch pop() {
                case let .int(i): stack.append(.int(-i))
                case let .float(d): stack.append(.float(-d))
                case let .bool(b): stack.append(.int(b ? -1 : 0))
                case let v: throw fault(.type, "Expected number, got \(v.typeName)")
                }
            case .not: stack.append(.bool(!pop().truthy))
            case let .compare(c):
                let r = pop(), l = pop()
                stack.append(.bool(try compare(c, l, r)))
            case let .jump(t): frames[fi].pc = t
            case let .jumpIfFalse(t): if !pop().truthy { frames[fi].pc = t }
            case let .jumpIfFalseOrPop(t): if !stack.last!.truthy { frames[fi].pc = t } else { _ = pop() }
            case let .jumpIfTrueOrPop(t): if stack.last!.truthy { frames[fi].pc = t } else { _ = pop() }
            case let .call(argc):
                let args = Array(stack.suffix(argc))
                stack.removeLast(argc)
                let fn = pop()
                switch fn {
                case let .function(i):
                    try push(program.functions[i], args)
                case let .builtin(name):
                    stack.append(try callBuiltin(name, args))
                default: throw fault(.type, "'\(fn.typeName)' object is not callable")
                }
            case let .callMethod(ni, argc):
                let name = program.names[ni]
                let args = Array(stack.suffix(argc))
                stack.removeLast(argc)
                let obj = pop()
                stack.append(try callMethod(obj, name, args))
            case let .loadAttr(ni):
                let name = program.names[ni]
                let obj = pop()
                guard case let .module(m) = obj else { throw fault(.type, "'\(obj.typeName)' has no attribute '\(name)'") }
                if m == "math" {
                    switch name {
                    case "pi": stack.append(.float(.pi)); continue
                    case "e": stack.append(.float(M_E)); continue
                    case "inf": stack.append(.float(.infinity)); continue
                    case "tau": stack.append(.float(2 * .pi)); continue
                    default: break
                    }
                    guard Builtins.math.contains(name) else { throw fault(.name, "math has no attribute '\(name)'") }
                }
                stack.append(.builtin("\(m).\(name)"))
            case .index:
                let idx = pop(), obj = pop()
                stack.append(try index(obj, idx))
            case .storeIndex:
                let idx = pop(), obj = pop(), v = pop()
                switch obj {
                case let .list(l):
                    let i = try listIndex(idx, l.items.count)
                    l.items[i] = v
                case let .dict(d):
                    guard let k = idx.dictKey else { throw fault(.type, "Unhashable key \(idx.typeName)") }
                    d.set(k, key: idx, v)
                default: throw fault(.type, "'\(obj.typeName)' does not support item assignment")
                }
            case let .buildList(n):
                let items = Array(stack.suffix(n)); stack.removeLast(n)
                try alloc(n + 1)
                stack.append(.list(ListRef(items)))
            case let .buildTuple(n):
                let items = Array(stack.suffix(n)); stack.removeLast(n)
                stack.append(.tuple(items))
            case let .buildDict(n):
                let items = Array(stack.suffix(n * 2)); stack.removeLast(n * 2)
                try alloc(n * 2 + 1)
                let d = DictRef()
                for j in 0..<n {
                    guard let k = items[2 * j].dictKey else { throw fault(.type, "Unhashable key \(items[2 * j].typeName)") }
                    d.set(k, key: items[2 * j], items[2 * j + 1])
                }
                stack.append(.dict(d))
            case let .unpack(n):
                let v = pop()
                let items: [Value]
                switch v {
                case let .tuple(t): items = t
                case let .list(l): items = l.items
                default: throw fault(.type, "Cannot unpack \(v.typeName)")
                }
                guard items.count == n else {
                    throw fault(.value, "Expected \(n) values to unpack, got \(items.count)")
                }
                stack.append(contentsOf: items.reversed())
            case .ret:
                let v = pop()
                let f = frames.removeLast()
                if frames.isEmpty { return v }
                stack.removeSubrange(f.base...)
                stack.append(v)
            case .pop: _ = pop()
            case .getIter:
                let v = pop()
                switch v {
                case let .list(l): stack.append(.iter(IterRef(l.items)))
                case let .tuple(t): stack.append(.iter(IterRef(t)))
                case let .dict(d): stack.append(.iter(IterRef(d.order.map { d.map[$0]!.key })))
                case let .str(s): stack.append(.iter(IterRef(s.map { .str(String($0)) })))
                default: throw fault(.type, "'\(v.typeName)' is not iterable")
                }
            case let .forIter(t):
                guard case let .iter(it) = stack.last! else { throw fault(.type, "Bad iterator") }
                if it.i < it.items.count { stack.append(it.items[it.i]); it.i += 1 } else {
                    _ = pop(); frames[fi].pc = t
                }
            case let .makeFunction(i): stack.append(.function(i))
            }
        }
    }

    func push(_ code: Code, _ args: [Value]) throws(VMFault) {
        guard frames.count < Self.maxDepth else { throw fault(.recursion, "Recursion deeper than 64") }
        guard args.count == code.params else {
            throw fault(.type, "\(code.name)() takes \(code.params) arguments, got \(args.count)")
        }
        var locals = [Value?](repeating: nil, count: code.nlocals)
        for (i, a) in args.enumerated() { locals[i] = a }
        frames.append(Frame(code: code, pc: 0, locals: locals, base: stack.count))
    }

    func alloc(_ n: Int) throws(VMFault) {
        heapUsed += n
        if heapUsed > Self.heapCap { throw fault(.heap, "Memory over 1 MB") }
    }

    func listIndex(_ idx: Value, _ count: Int) throws(VMFault) -> Int {
        guard case var .int(i) = idx else {
            if case let .bool(b) = idx { return b ? 1 : 0 }
            throw fault(.type, "Expected int, got \(idx.typeName)")
        }
        if i < 0 { i += count }
        guard i >= 0 && i < count else {
            if case let .int(orig) = idx { throw fault(.index, "Index \(orig) out of range for length \(count)") }
            throw fault(.index, "Index out of range")
        }
        return i
    }

    func index(_ obj: Value, _ idx: Value) throws(VMFault) -> Value {
        switch obj {
        case let .list(l): return l.items[try listIndex(idx, l.items.count)]
        case let .tuple(t): return t[try listIndex(idx, t.count)]
        case let .str(s):
            let chars = Array(s)
            return .str(String(chars[try listIndex(idx, chars.count)]))
        case let .dict(d):
            guard let k = idx.dictKey, let v = d.map[k] else { throw fault(.key, "Key \(idx.quoted) not in dict") }
            return v.value
        default: throw fault(.type, "'\(obj.typeName)' is not subscriptable")
        }
    }

    func binary(_ op: BinOp, _ l: Value, _ r: Value) throws(VMFault) -> Value {
        switch (op, l, r) {
        case let (.add, .str(a), .str(b)): return .str(a + b)
        case let (.add, .list(a), .list(b)): try alloc(a.items.count + b.items.count); return .list(ListRef(a.items + b.items))
        case let (.add, .tuple(a), .tuple(b)): return .tuple(a + b)
        case let (.mul, .list(a), .int(n)):
            try alloc(a.items.count * max(n, 0))
            return .list(ListRef(Array([[Value]](repeating: a.items, count: max(n, 0)).joined())))
        case let (.mul, .str(a), .int(n)): return .str(String(repeating: a, count: max(n, 0)))
        default: break
        }
        if case let .int(a) = l.intLike, case let .int(b) = r.intLike {
            switch op {
            case .add: let (v, o) = a.addingReportingOverflow(b); return o ? .float(Double(a) + Double(b)) : .int(v)
            case .sub: let (v, o) = a.subtractingReportingOverflow(b); return o ? .float(Double(a) - Double(b)) : .int(v)
            case .mul: let (v, o) = a.multipliedReportingOverflow(by: b); return o ? .float(Double(a) * Double(b)) : .int(v)
            case .div:
                guard b != 0 else { throw fault(.div0, "Division by zero") }
                return .float(Double(a) / Double(b))
            case .floordiv:
                guard b != 0 else { throw fault(.div0, "Division by zero") }
                return .int(Int((Double(a) / Double(b)).rounded(.down)))
            case .mod:
                guard b != 0 else { throw fault(.div0, "Division by zero") }
                let m = a % b
                return .int(m != 0 && (m < 0) != (b < 0) ? m + b : m)
            case .pow:
                if b >= 0 && b < 64 {
                    var r = 1, o = false
                    for _ in 0..<b { (r, o) = r.multipliedReportingOverflow(by: a); if o { break } }
                    if !o { return .int(r) }
                }
                return .float(pow(Double(a), Double(b)))
            }
        }
        guard let a = l.asDouble, let b = r.asDouble else {
            throw fault(.type, "Unsupported operand types \(l.typeName) and \(r.typeName)")
        }
        switch op {
        case .add: return .float(a + b)
        case .sub: return .float(a - b)
        case .mul: return .float(a * b)
        case .div:
            guard b != 0 else { throw fault(.div0, "Division by zero") }
            return .float(a / b)
        case .floordiv:
            guard b != 0 else { throw fault(.div0, "Division by zero") }
            return .float((a / b).rounded(.down))
        case .mod:
            guard b != 0 else { throw fault(.div0, "Division by zero") }
            let m = a.truncatingRemainder(dividingBy: b)
            return .float(m != 0 && (m < 0) != (b < 0) ? m + b : m)
        case .pow: return .float(pow(a, b))
        }
    }

    func compare(_ c: CmpOp, _ l: Value, _ r: Value) throws(VMFault) -> Bool {
        switch c {
        case .eq: return valuesEqual(l, r)
        case .ne: return !valuesEqual(l, r)
        case .isOp, .isNot:
            let same: Bool
            switch (l, r) {
            case (.none, .none): same = true
            case let (.bool(a), .bool(b)): same = a == b
            case let (.list(a), .list(b)): same = a === b
            case let (.dict(a), .dict(b)): same = a === b
            default: same = false
            }
            return c == .isOp ? same : !same
        case .isIn, .notIn:
            let found: Bool
            switch r {
            case let .list(lst): found = lst.items.contains { valuesEqual($0, l) }
            case let .tuple(t): found = t.contains { valuesEqual($0, l) }
            case let .dict(d): found = l.dictKey.map { d.map[$0] != nil } ?? false
            case let .str(s):
                guard case let .str(sub) = l else { throw fault(.type, "'in <string>' requires string") }
                found = s.contains(sub)
            default: throw fault(.type, "Argument of type '\(r.typeName)' is not iterable")
            }
            return c == .isIn ? found : !found
        case .lt, .gt, .le, .ge:
            let ord: Int
            if let a = l.asDouble, let b = r.asDouble { ord = a < b ? -1 : (a > b ? 1 : 0) }
            else if case let .str(a) = l, case let .str(b) = r { ord = a < b ? -1 : (a > b ? 1 : 0) }
            else { throw fault(.type, "Cannot compare \(l.typeName) and \(r.typeName)") }
            switch c { case .lt: return ord < 0; case .gt: return ord > 0; case .le: return ord <= 0; default: return ord >= 0 }
        }
    }

    func callMethod(_ obj: Value, _ name: String, _ args: [Value]) throws(VMFault) -> Value {
        switch obj {
        case let .module(m):
            return try callBuiltin("\(m).\(name)", args)
        case let .list(l):
            switch (name, args.count) {
            case ("append", 1): try alloc(1); l.items.append(args[0]); return .none
            case ("pop", 0):
                guard !l.items.isEmpty else { throw fault(.index, "pop from empty list") }
                return l.items.removeLast()
            case ("pop", 1):
                let i = try listIndex(args[0], l.items.count); return l.items.remove(at: i)
            case ("insert", 2):
                guard case var .int(i) = args[0] else { throw fault(.type, "Expected int, got \(args[0].typeName)") }
                if i < 0 { i += l.items.count }
                try alloc(1)
                l.items.insert(args[1], at: min(max(i, 0), l.items.count)); return .none
            case ("index", 1):
                guard let i = l.items.firstIndex(where: { valuesEqual($0, args[0]) }) else { throw fault(.value, "Value not in list") }
                return .int(i)
            case ("clear", 0): l.items.removeAll(); return .none
            case ("reverse", 0): l.items.reverse(); return .none
            default: break
            }
        case let .dict(d):
            switch (name, args.count) {
            case ("get", 1), ("get", 2):
                if let k = args[0].dictKey, let v = d.map[k] { return v.value }
                return args.count == 2 ? args[1] : .none
            case ("keys", 0): return .list(ListRef(d.order.map { d.map[$0]!.key }))
            case ("values", 0): return .list(ListRef(d.order.map { d.map[$0]!.value }))
            case ("items", 0): return .list(ListRef(d.order.map { .tuple([d.map[$0]!.key, d.map[$0]!.value]) }))
            default: break
            }
        default: break
        }
        throw fault(.type, "'\(obj.typeName)' has no method '\(name)' taking \(args.count) arguments")
    }

    func callBuiltin(_ name: String, _ args: [Value]) throws(VMFault) -> Value {
        if name.hasPrefix("craft.") {
            guard let host else { throw fault(.name, "craft is not connected") }
            do { return try host.craftCall(String(name.dropFirst(6)), args) } catch let f as VMFault {
                var f = f; f.line = currentLine; throw f
            } catch { throw fault(.value, "\(error)") }
        }
        if name.hasPrefix("math.") { return try Builtins.math(String(name.dropFirst(5)), args, self) }
        return try Builtins.call(name, args, self)
    }
}

extension Value {
    var intLike: Value? {
        switch self {
        case .int: self
        case let .bool(b): .int(b ? 1 : 0)
        default: nil
        }
    }
}
