import Foundation

enum BinOp { case add, sub, mul, div, floordiv, mod, pow }
enum CmpOp { case eq, ne, lt, gt, le, ge, isIn, notIn, isOp, isNot }

enum Op {
    case const(Int)
    case loadLocal(Int), storeLocal(Int), loadGlobal(Int), storeGlobal(Int)
    case binary(BinOp)
    case neg, not
    case compare(CmpOp)
    case jump(Int), jumpIfFalse(Int), jumpIfFalseOrPop(Int), jumpIfTrueOrPop(Int)
    case call(Int)
    case callMethod(Int, Int)
    case loadAttr(Int)
    case index, storeIndex
    case buildList(Int), buildTuple(Int), buildDict(Int)
    case unpack(Int)
    case ret, pop, getIter, forIter(Int)
    case makeFunction(Int)
}

final class Code {
    let name: String
    let params: Int
    var nlocals = 0
    var localNames: [String] = []
    var ops: [Op] = []
    var lines: [Int] = []
    init(name: String, params: Int) { self.name = name; self.params = params }
}

/// Compiled module: module-level code, functions, constants and global names.
public final class Program {
    var module = Code(name: "<module>", params: 0)
    var functions: [Code] = []
    var consts: [Value] = []
    var names: [String] = []          // attribute / method names
    var globals: [String] = []
    var globalIndex: [String: Int] = [:]
    public internal(set) var functionNames: [String] = []
    /// Total bytecode operations in the module and every function, for the compile summary.
    public var opCount: Int { module.ops.count + functions.reduce(0) { $0 + $1.ops.count } }

    func global(_ n: String) -> Int {
        if let i = globalIndex[n] { return i }
        globals.append(n); globalIndex[n] = globals.count - 1
        return globals.count - 1
    }
}

public enum Compiler {
    public static func compile(_ source: String) throws -> Program {
        let toks = try Lexer.tokenize(source)
        var parser = Parser(toks)
        let stmts = try parser.parseProgram()
        let prog = Program()
        var gen = Gen(prog: prog, code: prog.module, locals: nil)
        try gen.block(stmts)
        gen.emitConst(.none, line: stmts.last?.line ?? 1)
        gen.emit(.ret, line: stmts.last?.line ?? 1)
        return prog
    }
}

struct Gen {
    let prog: Program
    let code: Code
    var locals: [String: Int]?           // nil at module level
    var loops: [(isFor: Bool, continueTarget: Int, breaks: [Int], continues: [Int])] = []
    var line = 1

    init(prog: Program, code: Code, locals: [String: Int]?) {
        self.prog = prog; self.code = code; self.locals = locals
    }

    mutating func emit(_ op: Op, line: Int? = nil) {
        code.ops.append(op); code.lines.append(line ?? self.line)
    }
    var here: Int { code.ops.count }
    mutating func patch(_ at: Int, to target: Int) {
        switch code.ops[at] {
        case .jump: code.ops[at] = .jump(target)
        case .jumpIfFalse: code.ops[at] = .jumpIfFalse(target)
        case .jumpIfFalseOrPop: code.ops[at] = .jumpIfFalseOrPop(target)
        case .jumpIfTrueOrPop: code.ops[at] = .jumpIfTrueOrPop(target)
        case .forIter: code.ops[at] = .forIter(target)
        default: break
        }
    }

    mutating func emitConst(_ v: Value, line: Int? = nil) {
        prog.consts.append(v); emit(.const(prog.consts.count - 1), line: line)
    }

    func nameIndex(_ n: String) -> Int {
        if let i = prog.names.firstIndex(of: n) { return i }
        prog.names.append(n); return prog.names.count - 1
    }

    mutating func block(_ stmts: [SNode]) throws {
        for s in stmts { try stmt(s) }
    }

    mutating func load(_ n: String) {
        if let l = locals?[n] { emit(.loadLocal(l)) } else { emit(.loadGlobal(prog.global(n))) }
    }
    mutating func store(_ n: String) {
        if let l = locals?[n] { emit(.storeLocal(l)) } else { emit(.storeGlobal(prog.global(n))) }
    }

    mutating func storeTarget(_ t: Expr) throws {
        switch t {
        case let .name(n): store(n)
        case let .index(obj, idx):
            // stack: value -> need obj, idx, value
            try expr(obj); try expr(idx); emit(.storeIndex)
        case let .tuple(items), let .list(items):
            emit(.unpack(items.count))
            for x in items { try storeTarget(x) }
        case .attr: throw CompileError("Attribute assignment is not supported", line: line)
        default: throw CompileError("Cannot assign to this expression", line: line)
        }
    }

    mutating func stmt(_ s: SNode) throws {
        line = s.line
        switch s.value {
        case let .expr(e): try expr(e); emit(.pop)
        case let .assign(targets, value):
            try expr(value)
            try storeTarget(targets[0])
        case let .augAssign(target, op, value):
            switch target {
            case let .name(n):
                load(n); try expr(value); emit(.binary(binOp(op))); store(n)
            case let .index(obj, idx):
                try expr(obj); try expr(idx); emit(.index)
                try expr(value); emit(.binary(binOp(op)))
                try expr(obj); try expr(idx); emit(.storeIndex)
            default: throw CompileError("Cannot assign to this expression", line: line)
            }
        case let .ifS(branches, els):
            var ends: [Int] = []
            for (cond, body) in branches {
                try expr(cond)
                let jf = here; emit(.jumpIfFalse(-1))
                try block(body)
                ends.append(here); emit(.jump(-1))
                patch(jf, to: here)
            }
            if let els { try block(els) }
            for e in ends { patch(e, to: here) }
        case let .whileS(cond, body):
            let start = here
            try expr(cond)
            let jf = here; emit(.jumpIfFalse(-1))
            loops.append((false, start, [], []))
            try block(body)
            emit(.jump(start))
            let l = loops.removeLast()
            patch(jf, to: here)
            for b in l.breaks { patch(b, to: here) }
        case let .forS(names, iter, body):
            try expr(iter)
            emit(.getIter)
            let top = here
            emit(.forIter(-1))
            if names.count == 1 { store(names[0]) } else {
                emit(.unpack(names.count)); for n in names { store(n) }
            }
            loops.append((true, top, [], []))
            try block(body)
            emit(.jump(top))
            let l = loops.removeLast()
            patch(top, to: here)
            // breaks land on a pop of the iterator
            let exit = here
            if !l.breaks.isEmpty {
                let skip = here; emit(.jump(-1))
                let brk = here; emit(.pop)
                for b in l.breaks { patch(b, to: brk) }
                patch(skip, to: here)
            }
            _ = exit
        case let .def(name, params, body):
            guard locals == nil else { throw CompileError("Nested functions are not supported", line: line) }
            let fcode = Code(name: name, params: params.count)
            var map: [String: Int] = [:]
            for p in params { map[p] = map.count }
            for n in Gen.assignedNames(body) where map[n] == nil { map[n] = map.count }
            fcode.nlocals = map.count
            fcode.localNames = map.sorted { $0.value < $1.value }.map(\.key)
            prog.functions.append(fcode)
            let fi = prog.functions.count - 1
            prog.functionNames.append(name)
            var g = Gen(prog: prog, code: fcode, locals: map)
            g.line = line
            try g.block(body)
            g.emitConst(.none, line: 0); g.emit(.ret, line: 0)      // implicit return: not a source line, never traced
            emit(.makeFunction(fi))
            store(name)
        case let .cdef(name, params, localNames, body):
            guard locals == nil else { throw CompileError("Nested functions are not supported", line: line) }
            let fcode = Code(name: name, params: params.count)
            var map: [String: Int] = [:]
            for p in params + localNames where map[p] == nil { map[p] = map.count }
            fcode.nlocals = map.count
            fcode.localNames = map.sorted { $0.value < $1.value }.map(\.key)
            prog.functions.append(fcode)
            let fi = prog.functions.count - 1
            prog.functionNames.append(name)
            var g = Gen(prog: prog, code: fcode, locals: map)
            g.line = line
            try g.block(body)
            g.emitConst(.none, line: 0); g.emit(.ret, line: 0)
            emit(.makeFunction(fi))
            store(name)
        case let .cfor(cond, body, step):
            let start = here
            try expr(cond)
            let jf = here; emit(.jumpIfFalse(-1))
            loops.append((false, -1, [], []))
            try block(body)
            let stepAt = here
            for c in loops[loops.count - 1].continues { patch(c, to: stepAt) }
            loops[loops.count - 1].continues = []
            try block(step)
            emit(.jump(start))
            let l = loops.removeLast()
            patch(jf, to: here)
            for b in l.breaks { patch(b, to: here) }
        case let .ret(e):
            guard locals != nil else { throw CompileError("'return' outside function", line: line) }
            if let e { try expr(e) } else { emitConst(.none) }
            emit(.ret)
        case .breakS:
            guard !loops.isEmpty else { throw CompileError("'break' outside loop", line: line) }
            loops[loops.count - 1].breaks.append(here); emit(.jump(-1))
        case .continueS:
            guard let l = loops.last else { throw CompileError("'continue' outside loop", line: line) }
            if l.continueTarget >= 0 { emit(.jump(l.continueTarget)) } else {
                loops[loops.count - 1].continues.append(here); emit(.jump(-1))
            }
        case .pass: break
        case let .importS(m):
            emitConst(.module(m)); store(m)
        }
    }

    static func assignedNames(_ body: [SNode]) -> [String] {
        var out: [String] = []
        func target(_ e: Expr) {
            switch e {
            case let .name(n): if !out.contains(n) { out.append(n) }
            case let .tuple(items), let .list(items): items.forEach(target)
            default: break
            }
        }
        func walk(_ s: [SNode]) {
            for n in s {
                switch n.value {
                case let .assign(ts, _): ts.forEach(target)
                case let .augAssign(t, _, _): target(t)
                case let .forS(names, _, b): names.forEach { target(.name($0)) }; walk(b)
                case let .ifS(br, els): br.forEach { walk($0.1) }; if let els { walk(els) }
                case let .whileS(_, b): walk(b)
                case let .importS(m): target(.name(m))
                default: break
                }
            }
        }
        walk(body)
        return out
    }

    func binOp(_ s: String) -> BinOp {
        switch s {
        case "+": .add; case "-": .sub; case "*": .mul; case "/": .div; case "//": .floordiv; case "%": .mod
        default: .pow
        }
    }

    mutating func expr(_ e: Expr) throws {
        switch e {
        case let .int(v): emitConst(.int(v))
        case let .float(v): emitConst(.float(v))
        case let .str(s): emitConst(.str(s))
        case let .bool(b): emitConst(.bool(b))
        case .none: emitConst(.none)
        case let .name(n): load(n)
        case let .binary(op, a, b): try expr(a); try expr(b); emit(.binary(binOp(op)))
        case let .unary(op, a):
            try expr(a); emit(op == "not" ? .not : .neg)
        case let .compare(op, a, b):
            try expr(a); try expr(b)
            let c: CmpOp = switch op {
            case "==": .eq; case "!=": .ne; case "<": .lt; case ">": .gt; case "<=": .le; case ">=": .ge
            case "in": .isIn; case "not in": .notIn; case "is": .isOp; default: .isNot
            }
            emit(.compare(c))
        case let .and(a, b):
            try expr(a); let j = here; emit(.jumpIfFalseOrPop(-1)); try expr(b); patch(j, to: here)
        case let .or(a, b):
            try expr(a); let j = here; emit(.jumpIfTrueOrPop(-1)); try expr(b); patch(j, to: here)
        case let .ifExp(c, t, f):
            try expr(c); let jf = here; emit(.jumpIfFalse(-1))
            try expr(t); let je = here; emit(.jump(-1))
            patch(jf, to: here); try expr(f); patch(je, to: here)
        case let .call(fn, args):
            if case let .attr(obj, name) = fn {
                try expr(obj)
                for a in args { try expr(a) }
                emit(.callMethod(nameIndex(name), args.count))
            } else {
                try expr(fn)
                for a in args { try expr(a) }
                emit(.call(args.count))
            }
        case let .attr(obj, name): try expr(obj); emit(.loadAttr(nameIndex(name)))
        case let .index(obj, idx): try expr(obj); try expr(idx); emit(.index)
        case let .list(items): for x in items { try expr(x) }; emit(.buildList(items.count))
        case let .tuple(items): for x in items { try expr(x) }; emit(.buildTuple(items.count))
        case let .dict(items): for (k, v) in items { try expr(k); try expr(v) }; emit(.buildDict(items.count))
        }
    }
}
