import Foundation

/// Source language of a guidance program. Both compile to the same `Program` and run on the same VM.
public enum SourceLanguage: String, Sendable, Codable, CaseIterable {
    case python, c
}

public extension Compiler {
    static func compile(_ source: String, language: SourceLanguage) throws -> Program {
        switch language {
        case .python: return try compile(source)
        case .c: return try CCompiler.compile(source)
        }
    }
}

public extension CompileError {
    /// gcc-style `line:col: error: message`.
    var gccStyle: String { "\(line):\(column): \(message)" }
}

/// C subset front end (specs/05). Lexes, parses and type-checks C, then lowers it to the Python-subset
/// syntax tree and reuses the bytecode generator, so both languages produce identical command streams.
///
/// Lowering: int, double and bool map to VM numbers; `int / int` truncates through `int()`; fixed arrays
/// and structs are lists (structs by field index); `vec3` is the (x, y, z) tuple the craft API returns.
/// Struct and array assignment shares the list (no copy). Functions get an explicit local list so a
/// function that assigns a global changes the global, as in C.
public enum CCompiler {
    public static func compile(_ source: String) throws -> Program {
        let toks = try CLexer.tokenize(source)
        var p = CParser(toks: toks)
        let stmts = try p.program()
        let prog = Program()
        var gen = Gen(prog: prog, code: prog.module, locals: nil)
        try gen.block(stmts)
        gen.emitConst(.none, line: stmts.last?.line ?? 1)
        gen.emit(.ret, line: stmts.last?.line ?? 1)
        return prog
    }
}

// MARK: Lexer

struct CToken {
    enum Kind: Equatable { case ident(String), int(Int), float(Double), string(String), op(String), eof }
    var kind: Kind
    var line: Int
    var col: Int
}

enum CLexer {
    static let ops3 = ["<<=", ">>="]
    static let ops2 = ["==", "!=", "<=", ">=", "&&", "||", "++", "--", "+=", "-=", "*=", "/=", "%=", "->", "<<", ">>"]
    static let ops1 = Set("+-*/%<>=()[]{},;.!?:&|^~")

    static func tokenize(_ source: String) throws -> [CToken] {
        var out: [CToken] = []
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\t", with: "    ")
            .components(separatedBy: "\n")
        var inComment = false
        for (li, raw) in lines.enumerated() {
            let line = li + 1
            let chars = Array(raw)
            var i = 0
            if !inComment, raw.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                let t = raw.trimmingCharacters(in: .whitespaces)
                let col = (chars.firstIndex(of: "#") ?? 0) + 1
                let body = t.dropFirst().trimmingCharacters(in: .whitespaces)
                if body.hasPrefix("include") {
                    let h = body.dropFirst("include".count).trimmingCharacters(in: .whitespaces)
                    if h == "<craft.h>" || h == "<math.h>" || h == "\"craft.h\"" || h == "<stdbool.h>" { continue }
                    throw CompileError("error: \(h) file not found; only <craft.h>, <math.h> and <stdbool.h> exist", line: line, column: col)
                }
                throw CompileError("error: preprocessor directive '#\(body.split(separator: " ").first ?? "")' is not supported; use const", line: line, column: col)
            }
            while i < chars.count {
                let c = chars[i], col = i + 1
                if inComment {
                    if c == "*", i + 1 < chars.count, chars[i + 1] == "/" { inComment = false; i += 2 } else { i += 1 }
                    continue
                }
                if c == " " { i += 1; continue }
                if c == "/", i + 1 < chars.count, chars[i + 1] == "/" { break }
                if c == "/", i + 1 < chars.count, chars[i + 1] == "*" { inComment = true; i += 2; continue }
                if c.isLetter || c == "_" {
                    var j = i
                    while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                    out.append(CToken(kind: .ident(String(chars[i..<j])), line: line, col: col)); i = j; continue
                }
                if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
                    var j = i, isFloat = false
                    while j < chars.count, chars[j].isNumber || chars[j] == "." ||
                            ((chars[j] == "e" || chars[j] == "E") && j + 1 < chars.count) ||
                            ((chars[j] == "-" || chars[j] == "+") && j > i && (chars[j - 1] == "e" || chars[j - 1] == "E")) {
                        if chars[j] == "." || chars[j] == "e" || chars[j] == "E" { isFloat = true }
                        j += 1
                    }
                    var text = String(chars[i..<j])
                    if j < chars.count, "fF".contains(chars[j]), isFloat { j += 1 }
                    if text.hasSuffix(".") { text += "0" }
                    if isFloat {
                        guard let v = Double(text) else { throw CompileError("error: invalid number '\(text)'", line: line, column: col) }
                        out.append(CToken(kind: .float(v), line: line, col: col))
                    } else {
                        guard let v = Int(text) else { throw CompileError("error: invalid number '\(text)'", line: line, column: col) }
                        out.append(CToken(kind: .int(v), line: line, col: col))
                    }
                    i = j; continue
                }
                if c == "\"" {
                    var j = i + 1, s = ""
                    while j < chars.count, chars[j] != "\"" {
                        if chars[j] == "\\", j + 1 < chars.count {
                            j += 1
                            switch chars[j] { case "n": s.append("\n"); case "t": s.append("\t"); default: s.append(chars[j]) }
                        } else { s.append(chars[j]) }
                        j += 1
                    }
                    if j >= chars.count { throw CompileError("error: missing terminating '\"' character", line: line, column: col) }
                    out.append(CToken(kind: .string(s), line: line, col: col)); i = j + 1; continue
                }
                let rest = String(chars[i..<min(i + 3, chars.count)])
                if let op = ops3.first(where: { rest.hasPrefix($0) }) ?? ops2.first(where: { rest.hasPrefix($0) }) {
                    out.append(CToken(kind: .op(op), line: line, col: col)); i += op.count; continue
                }
                if ops1.contains(c) { out.append(CToken(kind: .op(String(c)), line: line, col: col)); i += 1; continue }
                throw CompileError("error: stray '\(c)' in program", line: line, column: col)
            }
        }
        out.append(CToken(kind: .eof, line: max(1, lines.count), col: 1))
        return out
    }
}

// MARK: Types

indirect enum CType: Equatable, Sendable, CustomStringConvertible {
    case int, double, bool, void, vec3, string
    case strct(String)
    case array(CType, Int)

    var isNumeric: Bool { self == .int || self == .double || self == .bool }
    var description: String {
        switch self {
        case .int: "int"; case .double: "double"; case .bool: "bool"; case .void: "void"; case .vec3: "vec3"
        case .string: "const char *"
        case let .strct(n): "struct \(n)"
        case let .array(t, n): n > 0 ? "\(t)[\(n)]" : "\(t)[]"
        }
    }
}

struct CFunc {
    var ret: CType
    var params: [CType]
    var defined: Bool
}

/// Built-in header functions: (Python lowering, params, return).
enum CHeaders {
    enum Lower: Sendable { case craft(String), math(String), builtin(String), pow, lidarScan }
    struct Entry: Sendable { var lower: Lower; var params: [CType]?; var ret: CType }

    static let table: [String: Entry] = {
        var t: [String: Entry] = [:]
        for n in ["altitude", "fuel", "energy", "time", "mass", "thrust_max", "random", "temperature"] {
            t["craft_" + n] = Entry(lower: .craft(n), params: [], ret: .double)
        }
        for n in ["position", "velocity", "attitude", "next_gate", "goal", "goal_position"] {
            t["craft_" + n] = Entry(lower: .craft(n), params: [], ret: .vec3)
        }
        for n in ["set_throttle", "set_pitch", "set_yaw", "set_roll"] {
            t["craft_" + n] = Entry(lower: .craft(n), params: [.double], ret: .void)
        }
        t["craft_stage"] = Entry(lower: .craft("stage"), params: [], ret: .void)
        t["craft_log"] = Entry(lower: .craft("log"), params: nil, ret: .void)
        t["craft_plot"] = Entry(lower: .craft("plot"), params: [.string, .double], ret: .void)
        t["craft_lidar"] = Entry(lower: .craft("lidar"), params: [.double], ret: .double)
        t["craft_lidar_scan"] = Entry(lower: .lidarScan, params: [.array(.double, 0), .array(.double, 0)], ret: .int)
        for n in ["sin", "cos", "tan", "asin", "acos", "atan", "sqrt", "exp", "log", "floor", "ceil", "fabs", "radians", "degrees"] {
            t[n] = Entry(lower: .math(n), params: [.double], ret: .double)
        }
        for n in ["atan2", "hypot", "copysign"] { t[n] = Entry(lower: .math(n), params: [.double, .double], ret: .double) }
        t["clamp"] = Entry(lower: .math("clamp"), params: [.double, .double, .double], ret: .double)
        t["pow"] = Entry(lower: .pow, params: [.double, .double], ret: .double)
        t["fmin"] = Entry(lower: .builtin("min"), params: [.double, .double], ret: .double)
        t["fmax"] = Entry(lower: .builtin("max"), params: [.double, .double], ret: .double)
        t["abs"] = Entry(lower: .builtin("abs"), params: [.int], ret: .int)
        return t
    }()

    /// Names the lowering itself calls; user identifiers with these names are renamed.
    static let reserved: Set<String> = ["craft", "math", "int", "float", "bool", "len", "min", "max", "abs", "range",
                                        "round", "str", "print", "sum", "list"]
}

// MARK: Parser + type checker + lowering

struct CParser {
    var toks: [CToken]
    var i = 0
    var structs: [String: [(name: String, type: CType)]] = ["vec3": [("x", .double), ("y", .double), ("z", .double)]]
    var typedefs: [String: CType] = ["vec3": .vec3]
    var globals: [String: (type: CType, py: String, isConst: Bool, constValue: Int?)] = [:]
    var funcs: [String: CFunc] = [:]
    // Function state
    var scopes: [[String: (type: CType, py: String, isConst: Bool, constValue: Int?)]] = []
    var localNames: [String] = []
    var currentRet: CType?
    var temp = 0
    var loopDepth = 0
    var switchDepth: [Int] = []          // loopDepth at each enclosing switch

    init(toks: [CToken]) { self.toks = toks }

    // MARK: Token helpers

    var cur: CToken { toks[i] }
    mutating func advance() -> CToken { let t = toks[i]; if i < toks.count - 1 { i += 1 }; return t }
    func err(_ msg: String, _ t: CToken? = nil) -> CompileError {
        let t = t ?? cur
        return CompileError("error: " + msg, line: t.line, column: t.col)
    }
    func isOp(_ s: String) -> Bool { if case .op(s) = cur.kind { return true }; return false }
    func isIdent(_ s: String) -> Bool { if case .ident(s) = cur.kind { return true }; return false }
    func peekOp(_ s: String, _ k: Int) -> Bool {
        guard i + k < toks.count else { return false }
        if case .op(s) = toks[i + k].kind { return true }; return false
    }
    mutating func expectOp(_ s: String) throws {
        guard isOp(s) else { throw err("expected '\(s)'\(describeCur())") }
        _ = advance()
    }
    func describeCur() -> String {
        switch cur.kind {
        case let .ident(n): " before '\(n)'"
        case let .op(o): " before '\(o)' token"
        case .eof: " at end of input"
        default: ""
        }
    }
    mutating func ident() throws -> (String, CToken) {
        let t = cur
        guard case let .ident(n) = t.kind, !CParser.keywords.contains(n) else { throw err("expected identifier\(describeCur())") }
        _ = advance(); return (n, t)
    }

    static let keywords: Set<String> = ["int", "double", "float", "bool", "_Bool", "void", "const", "struct", "typedef",
                                        "if", "else", "while", "do", "for", "switch", "case", "default", "break", "continue",
                                        "return", "true", "false", "unsigned", "long", "char", "static", "goto"]

    func pyName(_ n: String) -> String { CHeaders.reserved.contains(n) ? "c_" + n : n }

    // MARK: Types

    var startsType: Bool {
        guard case let .ident(n) = cur.kind else { return false }
        return ["int", "double", "float", "bool", "_Bool", "void", "const", "struct", "static", "unsigned", "long", "char"]
            .contains(n) || typedefs[n] != nil
    }

    /// Base type with qualifiers. Returns (type, isConst).
    mutating func baseType() throws -> (CType, Bool) {
        var isConst = false
        while isIdent("const") || isIdent("static") { if isIdent("const") { isConst = true }; _ = advance() }
        let t = cur
        guard case let .ident(n) = t.kind else { throw err("expected type\(describeCur())") }
        _ = advance()
        let ty: CType
        switch n {
        case "int", "long": ty = .int; while isIdent("long") || isIdent("int") { _ = advance() }
        case "unsigned": ty = .int; if isIdent("int") || isIdent("long") { _ = advance() }
        case "double", "float": ty = .double
        case "bool", "_Bool": ty = .bool
        case "void": ty = .void
        case "char": throw err("type 'char' is not supported; use string literals only in craft_log and craft_plot", t)
        case "struct":
            let (sn, st) = try ident()
            if isOp("{") {
                try structBody(sn)
                ty = .strct(sn)
            } else {
                guard structs[sn] != nil else { throw err("variable has incomplete type 'struct \(sn)'", st) }
                ty = sn == "vec3" ? .vec3 : .strct(sn)
            }
        default:
            guard let td = typedefs[n] else { throw err("unknown type name '\(n)'", t) }
            ty = td
        }
        while isIdent("const") { isConst = true; _ = advance() }
        if isOp("*") { throw err("pointers are not supported in this C subset", cur) }
        return (ty, isConst)
    }

    mutating func structBody(_ name: String) throws {
        if structs[name] != nil { throw err("redefinition of 'struct \(name)'") }
        try expectOp("{")
        var fields: [(String, CType)] = []
        while !isOp("}") {
            let (bt, _) = try baseType()
            repeat {
                let (fn, ft) = try ident()
                let ty = try arraySuffix(bt)
                if fields.contains(where: { $0.0 == fn }) { throw err("duplicate member '\(fn)'", ft) }
                if ty == .void { throw err("field '\(fn)' declared as void", ft) }
                fields.append((fn, ty))
            } while try consumeComma()
            try expectOp(";")
        }
        try expectOp("}")
        structs[name] = fields.map { (name: $0.0, type: $0.1) }
    }

    mutating func consumeComma() throws -> Bool { if isOp(",") { _ = advance(); return true }; return false }

    mutating func arraySuffix(_ base: CType, allowOpen: Bool = false) throws -> CType {
        var dims: [Int] = []
        while isOp("[") {
            let t = advance()
            if isOp("]") {
                guard allowOpen, dims.isEmpty else { throw err("array size missing", t) }
                _ = advance(); dims.append(0); continue
            }
            let n = try constInt()
            if n <= 0 { throw err("size of array is not positive", t) }
            try expectOp("]")
            dims.append(n)
        }
        var ty = base
        for d in dims.reversed() { ty = .array(ty, d) }
        return ty
    }

    /// Integer constant expression: literal, const int name, unary minus, + - * / of those.
    mutating func constInt() throws -> Int {
        var v = try constAtom()
        while isOp("+") || isOp("-") || isOp("*") || isOp("/") {
            let op = advance()
            let b = try constAtom()
            switch op.kind {
            case .op("+"): v += b; case .op("-"): v -= b; case .op("*"): v *= b
            default: guard b != 0 else { throw err("division by zero in constant expression", op) }; v /= b
            }
        }
        return v
    }
    mutating func constAtom() throws -> Int {
        let t = cur
        switch t.kind {
        case let .int(v): _ = advance(); return v
        case .op("-"): _ = advance(); return -(try constAtom())
        case .op("("): _ = advance(); let v = try constInt(); try expectOp(")"); return v
        case let .ident(n):
            if let s = lookup(n), let c = s.constValue { _ = advance(); return c }
            throw err("expression is not an integer constant expression", t)
        default: throw err("expression is not an integer constant expression", t)
        }
    }

    func lookup(_ n: String) -> (type: CType, py: String, isConst: Bool, constValue: Int?)? {
        for s in scopes.reversed() { if let v = s[n] { return v } }
        return globals[n]
    }

    // MARK: Program

    mutating func program() throws -> [SNode] {
        var out: [SNode] = [SNode(value: .importS("craft"), line: 1), SNode(value: .importS("math"), line: 1)]
        while cur.kind != .eof {
            if isOp(";") { _ = advance(); continue }
            if isIdent("typedef") {
                _ = advance()
                let t = cur
                let (bt, _) = try baseType()
                let (name, _) = try ident()
                if typedefs[name] != nil, typedefs[name] != bt { throw err("conflicting types for '\(name)'", t) }
                typedefs[name] = bt
                if case let .strct(sn) = bt, structs[name] == nil { structs[name] = structs[sn] }
                try expectOp(";")
                continue
            }
            let start = cur
            let (bt, isConst) = try baseType()
            if isOp(";") { _ = advance(); continue }          // struct declaration only
            let (name, nt) = try ident()
            if isOp("(") {
                if let f = try function(name, nt, ret: bt) { out.append(f) }
                continue
            }
            var first = true
            repeat {
                let (n, t) = first ? (name, nt) : try ident()
                first = false
                out += try declarator(n, t, base: bt, isConst: isConst, global: true)
            } while try consumeComma()
            _ = start
            try expectOp(";")
        }
        if let u = funcs["update"] {
            guard u.ret == .void, u.params == [.double] else {
                throw CompileError("error: 'update' must be declared 'void update(double dt)'", line: 1)
            }
        }
        if let s = funcs["setup"] {
            guard s.ret == .void, s.params.isEmpty else { throw CompileError("error: 'setup' must be declared 'void setup(void)'", line: 1) }
        }
        return out
    }

    /// One declared variable with optional initializer, lowered to an assignment.
    mutating func declarator(_ name: String, _ t: CToken, base: CType, isConst: Bool, global: Bool) throws -> [SNode] {
        let ty = try arraySuffix(base)
        if ty == .void { throw err("variable '\(name)' declared void", t) }
        if global {
            if globals[name] != nil || funcs[name] != nil { throw err("redefinition of '\(name)'", t) }
        } else if scopes[scopes.count - 1][name] != nil { throw err("redefinition of '\(name)'", t) }
        let py = global ? pyName(name) : newLocal(name)
        var value: Expr
        var constValue: Int?
        var pre: [SNode] = []
        if isOp("=") {
            _ = advance()
            if isOp("{") {
                value = try initList(ty)
            } else {
                let save = i
                if isConst, ty == .int, let c = try? constInt(), isOp(";") || isOp(",") { constValue = c; i = save }
                else { i = save }
                let (e, et, p) = try exprWithPrelude()
                pre = p
                value = try convert(e, from: et, to: ty, at: t)
            }
        } else {
            if isConst { throw err("uninitialized const '\(name)'", t) }
            value = defaultValue(ty)
        }
        let entry = (type: ty, py: py, isConst: isConst, constValue: constValue)
        if global { globals[name] = entry } else { scopes[scopes.count - 1][name] = entry }
        return pre + [SNode(value: .assign([.name(py)], value), line: t.line)]
    }

    mutating func newLocal(_ n: String) -> String {
        var py = pyName(n)
        var k = 2
        while localNames.contains(py) || funcs[py] != nil { py = pyName(n) + "__\(k)"; k += 1 }
        localNames.append(py)
        return py
    }
    mutating func newTemp(_ hint: String) -> String {
        temp += 1
        let n = "__\(hint)\(temp)"
        if currentRet != nil { localNames.append(n) }
        return n
    }

    func defaultValue(_ ty: CType) -> Expr {
        switch ty {
        case .int: .int(0)
        case .double: .float(0)
        case .bool: .bool(false)
        case .vec3: .list([.float(0), .float(0), .float(0)])
        case let .strct(n): .list((structs[n] ?? []).map { defaultValue($0.type) })
        case let .array(e, n): .list((0..<n).map { _ in defaultValue(e) })
        case .void, .string: .none
        }
    }

    mutating func initList(_ ty: CType) throws -> Expr {
        let open = cur
        try expectOp("{")
        var items: [Expr] = []
        let fieldTypes: [CType]
        switch ty {
        case let .array(e, n): fieldTypes = Array(repeating: e, count: n)
        case let .strct(s): fieldTypes = (structs[s] ?? []).map(\.type)
        case .vec3: fieldTypes = [.double, .double, .double]
        default: throw err("scalar initializer cannot be a brace list", open)
        }
        while !isOp("}") {
            guard items.count < fieldTypes.count else { throw err("excess elements in initializer") }
            let ft = fieldTypes[items.count]
            if isOp("{") { items.append(try initList(ft)) } else {
                let t = cur
                let (e, et) = try expression()
                items.append(try convert(e, from: et, to: ft, at: t))
            }
            if !(try consumeComma()) { break }
        }
        try expectOp("}")
        while items.count < fieldTypes.count { items.append(defaultValue(fieldTypes[items.count])) }
        return .list(items)
    }

    // MARK: Functions

    mutating func function(_ name: String, _ nt: CToken, ret: CType) throws -> SNode? {
        try expectOp("(")
        var params: [(String, CType, CToken)] = []
        if isIdent("void"), peekOp(")", 1) { _ = advance() }
        while !isOp(")") {
            let (bt, _) = try baseType()
            var pname = ""
            var pt = cur
            if case .ident = cur.kind { (pname, pt) = try ident() }
            let ty = try arraySuffix(bt, allowOpen: true)
            if ty == .void { throw err("parameter '\(pname)' has void type", pt) }
            params.append((pname, ty, pt))
            if !(try consumeComma()) { break }
        }
        try expectOp(")")
        let sig = CFunc(ret: ret, params: params.map(\.1), defined: false)
        if let prev = funcs[name] {
            if prev.ret != sig.ret || !zip(prev.params, sig.params).allSatisfy({ CParser.sameParam($0, $1) }) || prev.params.count != sig.params.count {
                throw err("conflicting types for '\(name)'", nt)
            }
        } else if globals[name] != nil { throw err("'\(name)' redeclared as different kind of symbol", nt) }
        if isOp(";") { _ = advance(); if funcs[name] == nil { funcs[name] = sig }; return nil }
        if funcs[name]?.defined == true { throw err("redefinition of '\(name)'", nt) }
        var def = sig; def.defined = true
        funcs[name] = def
        // Body
        scopes = [[:]]
        localNames = []
        currentRet = ret
        loopDepth = 0; switchDepth = []
        var pyParams: [String] = []
        for (pn, pty, pt) in params {
            guard !pn.isEmpty else { throw err("parameter name omitted", pt) }
            if scopes[0][pn] != nil { throw err("redefinition of parameter '\(pn)'", pt) }
            let py = newLocal(pn)
            pyParams.append(py)
            scopes[0][pn] = (pty, py, false, nil)
        }
        let line = nt.line
        let body = try block(newScope: false)
        let locals = localNames.filter { !pyParams.contains($0) }
        scopes = []; currentRet = nil
        return SNode(value: .cdef(pyName(name), pyParams, locals, body), line: line)
    }

    static func sameParam(_ a: CType, _ b: CType) -> Bool {
        if case let .array(ea, _) = a, case let .array(eb, _) = b { return sameParam(ea, eb) }
        return a == b
    }

    // MARK: Statements

    mutating func block(newScope: Bool = true) throws -> [SNode] {
        try expectOp("{")
        if newScope { scopes.append([:]) }
        var out: [SNode] = []
        while !isOp("}") {
            if cur.kind == .eof { throw err("expected '}' at end of input") }
            out += try statement()
        }
        _ = advance()
        if newScope { scopes.removeLast() }
        return out
    }

    /// A statement as a body: a block, or one statement in its own scope.
    mutating func body() throws -> [SNode] {
        if isOp("{") { return try block() }
        scopes.append([:]); defer { scopes.removeLast() }
        return try statement()
    }

    mutating func statement() throws -> [SNode] {
        let t = cur
        let line = t.line
        if isOp("{") { return try block() }
        if isOp(";") { _ = advance(); return [] }
        if startsType {
            let (bt, isConst) = try baseType()
            var out: [SNode] = []
            repeat {
                let (n, nt) = try ident()
                out += try declarator(n, nt, base: bt, isConst: isConst, global: false)
            } while try consumeComma()
            try expectOp(";")
            return out
        }
        guard case let .ident(kw) = t.kind else { return try exprStatement(terminator: ";") }
        switch kw {
        case "if":
            _ = advance()
            var branches: [(Expr, [SNode])] = []
            var els: [SNode]?
            try expectOp("(")
            let c = try condition()
            try expectOp(")")
            branches.append((c, try body()))
            while isIdent("else") {
                _ = advance()
                if isIdent("if") {
                    _ = advance(); try expectOp("(")
                    let c2 = try condition()
                    try expectOp(")")
                    branches.append((c2, try body()))
                } else { els = try body(); break }
            }
            return [SNode(value: .ifS(branches, els), line: line)]
        case "while":
            _ = advance(); try expectOp("(")
            let c = try condition()
            try expectOp(")")
            loopDepth += 1; defer { loopDepth -= 1 }
            return [SNode(value: .whileS(c, try body()), line: line)]
        case "do":
            _ = advance()
            loopDepth += 1
            let b = try body()
            loopDepth -= 1
            guard isIdent("while") else { throw err("expected 'while' in do/while loop") }
            _ = advance(); try expectOp("(")
            let c = try condition()
            try expectOp(")"); try expectOp(";")
            let exit = SNode(value: .ifS([(.unary("not", c), [SNode(value: .breakS, line: line)])], nil), line: line)
            return [SNode(value: .cfor(.bool(true), b, [exit]), line: line)]
        case "for":
            _ = advance(); try expectOp("(")
            scopes.append([:]); defer { scopes.removeLast() }
            var initS: [SNode] = []
            if isOp(";") { _ = advance() } else if startsType {
                let (bt, isConst) = try baseType()
                repeat {
                    let (n, nt) = try ident()
                    initS += try declarator(n, nt, base: bt, isConst: isConst, global: false)
                } while try consumeComma()
                try expectOp(";")
            } else { initS = try exprStatement(terminator: ";") }
            let c: Expr = isOp(";") ? .bool(true) : try condition()
            try expectOp(";")
            var step: [SNode] = []
            if !isOp(")") {
                repeat { step += try simpleStatement() } while try consumeComma()
            }
            try expectOp(")")
            loopDepth += 1
            let b = try body()
            loopDepth -= 1
            return initS + [SNode(value: .cfor(c, b, step), line: line)]
        case "switch":
            return try switchStatement(line)
        case "break":
            _ = advance(); try expectOp(";")
            guard loopDepth > 0 || !switchDepth.isEmpty else { throw err("break statement not within loop or switch", t) }
            return [SNode(value: .breakS, line: line)]
        case "continue":
            _ = advance(); try expectOp(";")
            guard loopDepth > 0 else { throw err("continue statement not within a loop", t) }
            if let s = switchDepth.last, s == loopDepth { throw err("continue inside switch is not supported in this C subset", t) }
            return [SNode(value: .continueS, line: line)]
        case "return":
            _ = advance()
            guard let ret = currentRet else { throw err("return outside function", t) }
            if isOp(";") {
                _ = advance()
                if ret != .void { throw err("non-void function should return a value", t) }
                return [SNode(value: .ret(nil), line: line)]
            }
            let vt = cur
            let (e, et, pre) = try exprWithPrelude()
            try expectOp(";")
            if ret == .void { throw err("void function should not return a value", vt) }
            return pre + [SNode(value: .ret(try convert(e, from: et, to: ret, at: vt)), line: line)]
        case "case", "default":
            throw err("'\(kw)' statement not in switch statement", t)
        case "else":
            throw err("expected expression before 'else'", t)
        case "goto":
            throw err("goto is not supported", t)
        default:
            return try exprStatement(terminator: ";")
        }
    }

    mutating func switchStatement(_ line: Int) throws -> [SNode] {
        _ = advance(); try expectOp("(")
        let st = cur
        let (e, et) = try expression()
        guard et == .int || et == .bool else { throw err("switch quantity not an integer", st) }
        try expectOp(")"); try expectOp("{")
        let sw = newTemp("sw"), matched = newTemp("m")
        var cases: [(values: [Int]?, body: [SNode])] = []      // nil values = default
        var allValues: [Int] = []
        switchDepth.append(loopDepth)
        scopes.append([:])
        while !isOp("}") {
            let t = cur
            if isIdent("case") {
                _ = advance()
                let v = try constInt()
                try expectOp(":")
                if allValues.contains(v) { throw err("duplicate case value '\(v)'", t) }
                allValues.append(v)
                if let last = cases.last, last.body.isEmpty, last.values != nil { cases[cases.count - 1].values!.append(v) }
                else { cases.append(([v], [])) }
            } else if isIdent("default") {
                _ = advance(); try expectOp(":")
                if cases.contains(where: { $0.values == nil }) { throw err("multiple default labels in one switch", t) }
                cases.append((nil, []))
            } else {
                guard !cases.isEmpty else { throw err("statement before the first case label", t) }
                cases[cases.count - 1].body += try statement()
            }
        }
        _ = advance()
        scopes.removeLast()
        switchDepth.removeLast()
        var inner: [SNode] = []
        for c in cases {
            let cond: Expr
            if let vs = c.values {
                cond = vs.map { Expr.compare("==", .name(sw), .int($0)) }.reduce(Expr.name(matched)) { .or($0, $1) }
            } else {
                let none = allValues.map { Expr.compare("!=", .name(sw), .int($0)) }.reduce(Expr.bool(true)) { .and($0, $1) }
                cond = .or(.name(matched), none)
            }
            inner.append(SNode(value: .ifS([(cond, [SNode(value: .assign([.name(matched)], .bool(true)), line: line)] + c.body)], nil), line: line))
        }
        inner.append(SNode(value: .breakS, line: line))
        return [SNode(value: .assign([.name(sw)], e), line: line), SNode(value: .assign([.name(matched)], .bool(false)), line: line),
                SNode(value: .whileS(.bool(true), inner), line: line)]
    }

    mutating func exprStatement(terminator: String) throws -> [SNode] {
        let s = try simpleStatement()
        try expectOp(terminator)
        return s
    }

    /// Assignment, increment, call or other expression, without the terminator.
    mutating func simpleStatement() throws -> [SNode] {
        let t = cur
        let line = t.line
        if isOp("++") || isOp("--") {
            let op = advance()
            let (lv, lt) = try lvalue()
            guard lt.isNumeric else { throw err("cannot increment value of type '\(lt)'", op) }
            return [SNode(value: .augAssign(lv, op.kind == .op("++") ? "+" : "-", .int(1)), line: line)]
        }
        let save = i
        // Try an lvalue followed by an assignment operator.
        if case .ident = cur.kind, let (lv, lt) = try? lvalue() {
            for op in ["=", "+=", "-=", "*=", "/=", "%="] where isOp(op) {
                let opTok = advance()
                if case let .array(_, _) = lt { throw err("assignment to expression with array type", opTok) }
                let vt = cur
                let (e, et, pre) = try exprWithPrelude()
                if op == "=" {
                    return pre + [SNode(value: .assign([lv], try convert(e, from: et, to: lt, at: vt)), line: line)]
                }
                guard lt.isNumeric, et.isNumeric else { throw err("invalid operands to binary \(op.dropLast()) (have '\(lt)' and '\(et)')", opTok) }
                let bop = String(op.dropLast())
                let combined = try arith(bop, lv, lt, e, et, at: opTok)
                return pre + [SNode(value: .assign([lv], try convert(combined.0, from: combined.1, to: lt, at: vt)), line: line)]
            }
            if isOp("++") || isOp("--") {
                let op = advance()
                guard lt.isNumeric else { throw err("cannot increment value of type '\(lt)'", op) }
                return [SNode(value: .augAssign(lv, op.kind == .op("++") ? "+" : "-", .int(1)), line: line)]
            }
        }
        i = save
        let (e, _, pre) = try exprWithPrelude()
        return pre + [SNode(value: .expr(e), line: line)]
    }

    /// Variable, array element or struct field that can be assigned.
    mutating func lvalue() throws -> (Expr, CType) {
        let (n, t) = try ident()
        guard let v = lookup(n) else { throw err("use of undeclared identifier '\(n)'", t) }
        if v.isConst {
            if !(isOp("[") || isOp(".")) { if isAssignAhead { throw err("assignment of read-only variable '\(n)'", t) } }
        }
        var e: Expr = .name(v.py), ty = v.type
        while true {
            if isOp("[") {
                let bt = advance()
                guard case let .array(el, _) = ty else { throw err("subscripted value is not an array", bt) }
                let it = cur
                let (ie, iet) = try expression()
                guard iet == .int || iet == .bool else { throw err("array subscript is not an integer", it) }
                try expectOp("]")
                e = .index(e, ie); ty = el
            } else if isOp(".") {
                let dt = advance()
                let (f, ft) = try ident()
                let (idx, fty) = try field(ty, f, ft, dt)
                e = .index(e, .int(idx)); ty = fty
            } else { break }
        }
        if v.isConst, isAssignAhead { throw err("assignment of read-only variable '\(n)'", t) }
        return (e, ty)
    }
    var isAssignAhead: Bool { ["=", "+=", "-=", "*=", "/=", "%=", "++", "--"].contains { isOp($0) } }

    func field(_ ty: CType, _ f: String, _ ft: CToken, _ dt: CToken) throws -> (Int, CType) {
        let fields: [(name: String, type: CType)]
        switch ty {
        case .vec3: fields = structs["vec3"]!
        case let .strct(s): fields = structs[s] ?? []
        default: throw err("request for member '\(f)' in something not a structure", dt)
        }
        guard let idx = fields.firstIndex(where: { $0.name == f }) else { throw err("'\(ty)' has no member named '\(f)'", ft) }
        return (idx, fields[idx].type)
    }

    // MARK: Expressions

    var prelude: [SNode] = []
    var preludeAllowed = false

    mutating func exprWithPrelude() throws -> (Expr, CType, [SNode]) {
        prelude = []; preludeAllowed = true
        defer { preludeAllowed = false; prelude = [] }
        let (e, t) = try expression()
        return (e, t, prelude)
    }

    mutating func condition() throws -> Expr {
        let t = cur
        let (e, ty) = try expression()
        guard ty.isNumeric else { throw err("used '\(ty)' type value where scalar is required", t) }
        return e
    }

    func convert(_ e: Expr, from: CType, to: CType, at t: CToken) throws -> Expr {
        if from == to { return e }
        switch (from, to) {
        case (.double, .int): return .call(.name("int"), [e])
        case (.int, .double), (.bool, .double): return .call(.name("float"), [e])
        case (.bool, .int): return .call(.name("int"), [e])
        case (.int, .bool), (.double, .bool): return .call(.name("bool"), [e])
        case let (.array(a, _), .array(b, _)) where CParser.sameParam(a, b): return e
        case (.vec3, .vec3): return e
        default:
            throw err("incompatible types when assigning to type '\(to)' from type '\(from)'", t)
        }
    }

    mutating func expression() throws -> (Expr, CType) {
        let (e, t) = try ternary()
        if isAssignAhead, !(isOp("++") || isOp("--")) { throw err("assignment inside an expression is not supported; make it a statement") }
        return (e, t)
    }

    mutating func ternary() throws -> (Expr, CType) {
        let ct = cur
        let (c, cty) = try logicOr()
        guard isOp("?") else { return (c, cty) }
        guard cty.isNumeric else { throw err("used '\(cty)' type value where scalar is required", ct) }
        _ = advance()
        let (a, at) = try expression()
        let colon = cur
        try expectOp(":")
        let (b, bt) = try ternary()
        if at.isNumeric && bt.isNumeric {
            let rt: CType = (at == .double || bt == .double) ? .double : .int
            return (.ifExp(cond: c, then: try convert(a, from: at, to: rt, at: colon), els: try convert(b, from: bt, to: rt, at: colon)), rt)
        }
        guard at == bt else { throw err("type mismatch in conditional expression ('\(at)' and '\(bt)')", colon) }
        return (.ifExp(cond: c, then: a, els: b), at)
    }

    mutating func logicOr() throws -> (Expr, CType) {
        var (a, at) = try logicAnd()
        while isOp("||") {
            let op = advance()
            let (b, bt) = try logicAnd()
            guard at.isNumeric, bt.isNumeric else { throw err("invalid operands to binary || (have '\(at)' and '\(bt)')", op) }
            a = .call(.name("bool"), [.or(a, b)]); at = .bool
        }
        return (a, at)
    }

    mutating func logicAnd() throws -> (Expr, CType) {
        var (a, at) = try equality()
        while isOp("&&") {
            let op = advance()
            let (b, bt) = try equality()
            guard at.isNumeric, bt.isNumeric else { throw err("invalid operands to binary && (have '\(at)' and '\(bt)')", op) }
            a = .call(.name("bool"), [.and(a, b)]); at = .bool
        }
        return (a, at)
    }

    mutating func equality() throws -> (Expr, CType) {
        var (a, at) = try relational()
        while isOp("==") || isOp("!=") {
            let op = advance()
            let (b, bt) = try relational()
            guard at.isNumeric, bt.isNumeric else { throw err("invalid operands to binary \(opText(op)) (have '\(at)' and '\(bt)')", op) }
            a = .compare(opText(op), a, b); at = .bool
        }
        return (a, at)
    }

    func opText(_ t: CToken) -> String { if case let .op(o) = t.kind { return o }; return "?" }

    mutating func relational() throws -> (Expr, CType) {
        var (a, at) = try additive()
        while isOp("<") || isOp(">") || isOp("<=") || isOp(">=") {
            let op = advance()
            let (b, bt) = try additive()
            guard at.isNumeric, bt.isNumeric else { throw err("invalid operands to binary \(opText(op)) (have '\(at)' and '\(bt)')", op) }
            a = .compare(opText(op), a, b); at = .bool
        }
        return (a, at)
    }

    mutating func additive() throws -> (Expr, CType) {
        var (a, at) = try multiplicative()
        while isOp("+") || isOp("-") {
            let op = advance()
            let (b, bt) = try multiplicative()
            (a, at) = try arith(opText(op), a, at, b, bt, at: op)
        }
        return (a, at)
    }

    mutating func multiplicative() throws -> (Expr, CType) {
        var (a, at) = try unary()
        while isOp("*") || isOp("/") || isOp("%") {
            let op = advance()
            let (b, bt) = try unary()
            (a, at) = try arith(opText(op), a, at, b, bt, at: op)
        }
        return (a, at)
    }

    /// Typed arithmetic with C semantics: int / int and int % int truncate toward zero.
    func arith(_ op: String, _ a: Expr, _ at: CType, _ b: Expr, _ bt: CType, at t: CToken) throws -> (Expr, CType) {
        guard at.isNumeric, bt.isNumeric else { throw err("invalid operands to binary \(op) (have '\(at)' and '\(bt)')", t) }
        let isInt = at != .double && bt != .double
        switch op {
        case "/":
            if isInt { return (.call(.name("int"), [.binary("/", a, b)]), .int) }
            return (.binary("/", a, b), .double)
        case "%":
            guard isInt else { throw err("invalid operands to binary % (have '\(at)' and '\(bt)')", t) }
            return (.binary("-", a, .binary("*", b, .call(.name("int"), [.binary("/", a, b)]))), .int)
        default:
            return (.binary(op, a, b), isInt ? .int : .double)
        }
    }

    mutating func unary() throws -> (Expr, CType) {
        let t = cur
        if isOp("-") || isOp("+") {
            _ = advance()
            let (e, ty) = try unary()
            guard ty.isNumeric else { throw err("wrong type argument to unary \(opText(t))", t) }
            let rt: CType = ty == .bool ? .int : ty
            if t.kind == .op("+") { return (e, rt) }
            if case let .int(v) = e { return (.int(-v), rt) }
            if case let .float(v) = e { return (.float(-v), rt) }
            return (.unary("-", e), rt)
        }
        if isOp("!") {
            _ = advance()
            let (e, ty) = try unary()
            guard ty.isNumeric else { throw err("wrong type argument to unary exclamation mark", t) }
            return (.unary("not", e), .bool)
        }
        if isOp("++") || isOp("--") { throw err("increment inside an expression is not supported; make it a statement", t) }
        if isOp("&") || isOp("*") { throw err("pointers are not supported in this C subset", t) }
        // Cast
        if isOp("("), i + 1 < toks.count, case let .ident(n) = toks[i + 1].kind,
           ["int", "double", "float", "bool", "_Bool"].contains(n), peekOp(")", 2) {
            _ = advance(); _ = advance(); _ = advance()
            let (e, ty) = try unary()
            guard ty.isNumeric else { throw err("aggregate value used where a scalar was expected", t) }
            switch n {
            case "int": return (ty == .int ? e : .call(.name("int"), [e]), .int)
            case "bool", "_Bool": return (.call(.name("bool"), [e]), .bool)
            default: return (ty == .double ? e : .call(.name("float"), [e]), .double)
            }
        }
        return try postfix()
    }

    mutating func postfix() throws -> (Expr, CType) {
        var (e, ty) = try primary()
        while true {
            if isOp("[") {
                let bt = advance()
                guard case let .array(el, _) = ty else { throw err("subscripted value is not an array", bt) }
                let it = cur
                let (ie, iet) = try expression()
                guard iet == .int || iet == .bool else { throw err("array subscript is not an integer", it) }
                try expectOp("]")
                e = .index(e, ie); ty = el
            } else if isOp(".") {
                let dt = advance()
                let (f, ft) = try ident()
                let (idx, fty) = try field(ty, f, ft, dt)
                e = .index(e, .int(idx)); ty = fty
            } else if isOp("->") {
                throw err("pointers are not supported in this C subset; use '.'")
            } else { break }
        }
        return (e, ty)
    }

    mutating func primary() throws -> (Expr, CType) {
        let t = cur
        switch t.kind {
        case let .int(v): _ = advance(); return (.int(v), .int)
        case let .float(v): _ = advance(); return (.float(v), .double)
        case let .string(s): _ = advance(); return (.str(s), .string)
        case .op("("):
            _ = advance()
            let r = try expression()
            try expectOp(")")
            return r
        case let .ident(n):
            _ = advance()
            if n == "true" { return (.bool(true), .bool) }
            if n == "false" { return (.bool(false), .bool) }
            if n == "M_PI" { return (.attr(.name("math"), "pi"), .double) }
            if n == "INFINITY" || n == "HUGE_VAL" { return (.attr(.name("math"), "inf"), .double) }
            if isOp("(") { return try call(n, t) }
            if CParser.keywords.contains(n) { throw err("expected expression before '\(n)'", t) }
            guard let v = lookup(n) else {
                if funcs[n] != nil { throw err("function '\(n)' used as a value; call it with ()", t) }
                throw err("use of undeclared identifier '\(n)'", t)
            }
            return (.name(v.py), v.type)
        case .eof: throw err("expected expression at end of input", t)
        default: throw err("expected expression before '\(opText(t))' token", t)
        }
    }

    mutating func args() throws -> [(Expr, CType, CToken)] {
        try expectOp("(")
        var out: [(Expr, CType, CToken)] = []
        while !isOp(")") {
            let t = cur
            let (e, ty) = try expression()
            out.append((e, ty, t))
            if !(try consumeComma()) { break }
        }
        try expectOp(")")
        return out
    }

    mutating func call(_ n: String, _ t: CToken) throws -> (Expr, CType) {
        let a = try args()
        if let f = funcs[n] {
            guard a.count == f.params.count else {
                throw err("too \(a.count < f.params.count ? "few" : "many") arguments to function '\(n)' (expected \(f.params.count), have \(a.count))", t)
            }
            var lowered: [Expr] = []
            for (k, (e, ty, at)) in a.enumerated() {
                let pt = f.params[k]
                if case let .array(pe, _) = pt {
                    guard case let .array(ae, _) = ty, CParser.sameParam(pe, ae) else {
                        throw err("incompatible type for argument \(k + 1) of '\(n)' (expected '\(pt)' but argument is of type '\(ty)')", at)
                    }
                    lowered.append(e)
                } else {
                    do { lowered.append(try convert(e, from: ty, to: pt, at: at)) } catch {
                        throw err("incompatible type for argument \(k + 1) of '\(n)' (expected '\(pt)' but argument is of type '\(ty)')", at)
                    }
                }
            }
            return (.call(.name(pyName(n)), lowered), f.ret)
        }
        guard let h = CHeaders.table[n] else {
            if n.hasPrefix("craft_") { throw err("'\(n)' is not part of <craft.h> in the C subset (see specs/05)", t) }
            throw err("implicit declaration of function '\(n)'", t)
        }
        var lowered: [Expr] = []
        if let ps = h.params {
            guard a.count == ps.count else {
                throw err("too \(a.count < ps.count ? "few" : "many") arguments to function '\(n)' (expected \(ps.count), have \(a.count))", t)
            }
            for (k, (e, ty, at)) in a.enumerated() {
                let pt = ps[k]
                switch pt {
                case .string:
                    guard ty == .string else { throw err("argument \(k + 1) of '\(n)' must be a string literal", at) }
                    lowered.append(e)
                case .array:
                    guard case .array(.double, _) = ty else { throw err("argument \(k + 1) of '\(n)' must be a double array", at) }
                    lowered.append(e)
                case .double:
                    guard ty.isNumeric else { throw err("incompatible type for argument \(k + 1) of '\(n)' (expected 'double' but argument is of type '\(ty)')", at) }
                    lowered.append(e)       // the VM treats int and double alike in host calls
                default:
                    lowered.append(try convert(e, from: ty, to: pt, at: at))
                }
            }
        } else {
            guard a.count == 1, a[0].1.isNumeric || a[0].1 == .string else { throw err("'\(n)' takes one number or string literal", t) }
            lowered = [a[0].0]
        }
        switch h.lower {
        case let .craft(m): return (.call(.attr(.name("craft"), m), lowered), h.ret)
        case let .math(m): return (.call(.attr(.name("math"), m), lowered), h.ret)
        case let .builtin(b): return (.call(.name(b), lowered), h.ret)
        case .pow: return (.binary("**", lowered[0], lowered[1]), .double)
        case .lidarScan:
            guard preludeAllowed, currentRet != nil else {
                throw err("craft_lidar_scan() must be a statement or the right side of an assignment inside a function", t)
            }
            let scan = newTemp("scan"), k = newTemp("k")
            let line = t.line
            func s(_ v: Stmt) -> SNode { SNode(value: v, line: line) }
            prelude += [
                s(.assign([.name(scan)], .call(.attr(.name("craft"), "lidar_scan"), []))),
                s(.assign([.name(k)], .int(0))),
                s(.whileS(.and(.compare("<", .name(k), .call(.name("len"), [.name(scan)])),
                               .compare("<", .name(k), .call(.name("len"), [lowered[0]]))), [
                    s(.assign([.index(lowered[0], .name(k))], .index(.index(.name(scan), .name(k)), .int(0)))),
                    s(.assign([.index(lowered[1], .name(k))], .index(.index(.name(scan), .name(k)), .int(1)))),
                    s(.augAssign(.name(k), "+", .int(1))),
                ])),
            ]
            return (.name(k), .int)
        }
    }
}
