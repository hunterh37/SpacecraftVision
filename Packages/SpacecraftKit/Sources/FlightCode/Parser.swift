import Foundation

indirect enum Expr {
    case int(Int), float(Double), str(String), bool(Bool), none
    case name(String)
    case binary(String, Expr, Expr)
    case unary(String, Expr)
    case compare(String, Expr, Expr)
    case and(Expr, Expr), or(Expr, Expr)
    case ifExp(cond: Expr, then: Expr, els: Expr)
    case call(Expr, [Expr])
    case attr(Expr, String)
    case index(Expr, Expr)
    case list([Expr]), tuple([Expr]), dict([(Expr, Expr)])
}

struct Node<T> { var value: T; var line: Int }

indirect enum Stmt {
    case expr(Expr)
    case assign([Expr], Expr)          // targets (single or tuple elements), value
    case augAssign(Expr, String, Expr)
    case ifS([(Expr, [Node<Stmt>])], [Node<Stmt>]?)
    case whileS(Expr, [Node<Stmt>])
    case forS([String], Expr, [Node<Stmt>])
    case def(String, [String], [Node<Stmt>])
    case ret(Expr?)
    case breakS, continueS, pass
    case importS(String)
}

typealias SNode = Node<Stmt>

struct Parser {
    var toks: [Token]
    var i = 0

    init(_ toks: [Token]) { self.toks = toks }

    var cur: Token { toks[i] }
    mutating func advance() -> Token { let t = toks[i]; if i < toks.count - 1 { i += 1 }; return t }

    func error(_ msg: String, _ t: Token? = nil) -> CompileError {
        let t = t ?? cur
        return CompileError(msg, line: t.line, column: t.col)
    }

    func isOp(_ s: String) -> Bool { if case .op(s) = cur.tok { return true }; return false }
    func isName(_ s: String) -> Bool { if case .name(s) = cur.tok { return true }; return false }

    mutating func expectOp(_ s: String) throws {
        guard isOp(s) else { throw error("Expected '\(s)'") }
        _ = advance()
    }

    mutating func expectName() throws -> String {
        guard case let .name(n) = cur.tok, !Lexer.keywords.contains(n) else { throw error("Expected a name") }
        _ = advance(); return n
    }

    mutating func parseProgram() throws -> [SNode] {
        var out: [SNode] = []
        while cur.tok != .eof {
            if cur.tok == .newline { _ = advance(); continue }
            out.append(contentsOf: try statement())
        }
        return out
    }

    mutating func block() throws -> [SNode] {
        try expectOp(":")
        if cur.tok != .newline {
            // Single-line suite: `if x: pass`
            return try simpleStatements()
        }
        _ = advance()
        guard cur.tok == .indent else { throw error("Expected an indented block") }
        _ = advance()
        var out: [SNode] = []
        while cur.tok != .dedent && cur.tok != .eof {
            if cur.tok == .newline { _ = advance(); continue }
            out.append(contentsOf: try statement())
        }
        if cur.tok == .dedent { _ = advance() }
        return out
    }

    mutating func statement() throws -> [SNode] {
        let line = cur.line
        if case let .name(kw) = cur.tok {
            switch kw {
            case "def":
                _ = advance()
                let name = try expectName()
                try expectOp("(")
                var params: [String] = []
                while !isOp(")") {
                    params.append(try expectName())
                    if isOp("=") { throw error("Default argument values are not supported") }
                    if !isOp(")") { try expectOp(",") }
                }
                _ = advance()
                if isOp("->") { _ = advance(); _ = try expression() }
                let body = try block()
                return [SNode(value: .def(name, params, body), line: line)]
            case "if":
                _ = advance()
                var branches: [(Expr, [SNode])] = [(try expression(), try block())]
                var els: [SNode]?
                while true {
                    if isName("elif") { _ = advance(); branches.append((try expression(), try block())); continue }
                    if isName("else") { _ = advance(); els = try block() }
                    break
                }
                return [SNode(value: .ifS(branches, els), line: line)]
            case "while":
                _ = advance()
                let c = try expression()
                return [SNode(value: .whileS(c, try block()), line: line)]
            case "for":
                _ = advance()
                var names = [try expectName()]
                while isOp(",") { _ = advance(); names.append(try expectName()) }
                guard isName("in") else { throw error("Expected 'in'") }
                _ = advance()
                let it = try expression()
                return [SNode(value: .forS(names, it, try block()), line: line)]
            case "class": throw error("Classes are not supported in v1")
            case "try": throw error("Exceptions are not supported in v1")
            case "lambda": throw error("lambda is not supported in v1")
            case "global": throw error("The global statement is not supported; mutate a module-level dict or list instead")
            case "from": throw error("Use 'import craft' or 'import math'")
            default: break
            }
        }
        return try simpleStatements()
    }

    mutating func simpleStatements() throws -> [SNode] {
        var out = [try simple()]
        while cur.tok == .op(";") { _ = advance(); if cur.tok == .newline { break }; out.append(try simple()) }
        guard cur.tok == .newline || cur.tok == .eof else { throw error("Expected end of line") }
        if cur.tok == .newline { _ = advance() }
        return out
    }

    mutating func simple() throws -> SNode {
        let line = cur.line
        if case let .name(kw) = cur.tok {
            switch kw {
            case "pass": _ = advance(); return SNode(value: .pass, line: line)
            case "break": _ = advance(); return SNode(value: .breakS, line: line)
            case "continue": _ = advance(); return SNode(value: .continueS, line: line)
            case "return":
                _ = advance()
                if cur.tok == .newline || cur.tok == .eof { return SNode(value: .ret(nil), line: line) }
                return SNode(value: .ret(try exprList()), line: line)
            case "import":
                _ = advance()
                let m = try expectName()
                guard m == "craft" || m == "math" else { throw error("Only 'craft' and 'math' can be imported") }
                return SNode(value: .importS(m), line: line)
            default: break
            }
        }
        let e = try exprList()
        if isOp("=") {
            var targets = [e]
            var value: Expr = e
            while isOp("=") { _ = advance(); value = try exprList(); targets.append(value) }
            targets.removeLast()
            guard targets.count == 1 else { throw error("Chained assignment is not supported") }
            try checkTarget(targets[0], line: line)
            return SNode(value: .assign(targets, value), line: line)
        }
        for op in ["+=", "-=", "*=", "/=", "//=", "%=", "**="] where isOp(op) {
            _ = advance()
            try checkTarget(e, line: line)
            return SNode(value: .augAssign(e, String(op.dropLast()), try expression()), line: line)
        }
        return SNode(value: .expr(e), line: line)
    }

    func checkTarget(_ e: Expr, line: Int) throws {
        switch e {
        case .name, .index, .attr: return
        case let .tuple(items), let .list(items): for x in items { try checkTarget(x, line: line) }
        default: throw CompileError("Cannot assign to this expression", line: line)
        }
    }

    /// Comma-separated expressions form a tuple.
    mutating func exprList() throws -> Expr {
        let first = try expression()
        guard isOp(",") else { return first }
        var items = [first]
        while isOp(",") {
            _ = advance()
            if cur.tok == .newline || isOp("=") || isOp(")") { break }
            items.append(try expression())
        }
        return .tuple(items)
    }

    mutating func expression() throws -> Expr {
        let e = try orExpr()
        if isName("if") {
            _ = advance()
            let c = try orExpr()
            guard isName("else") else { throw error("Expected 'else'") }
            _ = advance()
            return .ifExp(cond: c, then: e, els: try expression())
        }
        return e
    }

    mutating func orExpr() throws -> Expr {
        var e = try andExpr()
        while isName("or") { _ = advance(); e = .or(e, try andExpr()) }
        return e
    }

    mutating func andExpr() throws -> Expr {
        var e = try notExpr()
        while isName("and") { _ = advance(); e = .and(e, try notExpr()) }
        return e
    }

    mutating func notExpr() throws -> Expr {
        if isName("not") { _ = advance(); return .unary("not", try notExpr()) }
        return try comparison()
    }

    mutating func comparison() throws -> Expr {
        let first = try arith()
        var parts: [(String, Expr)] = []
        while true {
            var op: String?
            for o in ["==", "!=", "<", ">", "<=", ">="] where isOp(o) { op = o }
            if op != nil { _ = advance() }
            else if isName("in") { _ = advance(); op = "in" }
            else if isName("not") && i + 1 < toks.count && toks[i + 1].tok == .name("in") { _ = advance(); _ = advance(); op = "not in" }
            else if isName("is") {
                _ = advance()
                if isName("not") { _ = advance(); op = "is not" } else { op = "is" }
            }
            guard let o = op else { break }
            parts.append((o, try arith()))
        }
        guard !parts.isEmpty else { return first }
        // a < b < c  ->  (a < b) and (b < c)
        var left = first
        var result: Expr?
        for (o, right) in parts {
            let c = Expr.compare(o, left, right)
            result = result.map { .and($0, c) } ?? c
            left = right
        }
        return result!
    }

    mutating func arith() throws -> Expr {
        var e = try term()
        while isOp("+") || isOp("-") {
            let op = advance()
            guard case let .op(o) = op.tok else { break }
            e = .binary(o, e, try term())
        }
        return e
    }

    mutating func term() throws -> Expr {
        var e = try unary()
        while isOp("*") || isOp("/") || isOp("//") || isOp("%") {
            guard case let .op(o) = advance().tok else { break }
            e = .binary(o, e, try unary())
        }
        return e
    }

    mutating func unary() throws -> Expr {
        if isOp("-") { _ = advance(); return .unary("-", try unary()) }
        if isOp("+") { _ = advance(); return try unary() }
        return try power()
    }

    mutating func power() throws -> Expr {
        let base = try postfix()
        if isOp("**") { _ = advance(); return .binary("**", base, try unary()) }
        return base
    }

    mutating func postfix() throws -> Expr {
        var e = try atom()
        while true {
            if isOp("(") {
                _ = advance()
                var args: [Expr] = []
                while !isOp(")") {
                    if case .name = cur.tok, i + 1 < toks.count, toks[i + 1].tok == .op("=") {
                        throw error("Keyword arguments are not supported")
                    }
                    args.append(try expression())
                    if !isOp(")") { try expectOp(",") }
                }
                _ = advance()
                e = .call(e, args)
            } else if isOp("[") {
                _ = advance()
                if isOp(":") { throw error("Slices are not supported in v1") }
                let idx = try exprList()
                if isOp(":") { throw error("Slices are not supported in v1") }
                try expectOp("]")
                e = .index(e, idx)
            } else if isOp(".") {
                _ = advance()
                guard case let .name(n) = cur.tok else { throw error("Expected attribute name") }
                _ = advance()
                e = .attr(e, n)
            } else { break }
        }
        return e
    }

    mutating func atom() throws -> Expr {
        let t = cur
        switch t.tok {
        case let .int(v): _ = advance(); return .int(v)
        case let .float(v): _ = advance(); return .float(v)
        case let .string(s):
            _ = advance()
            var s = s
            while case let .string(more) = cur.tok { s += more; _ = advance() }
            return .str(s)
        case let .name(n):
            switch n {
            case "True": _ = advance(); return .bool(true)
            case "False": _ = advance(); return .bool(false)
            case "None": _ = advance(); return .none
            case "lambda": throw error("lambda is not supported in v1")
            default:
                if Lexer.keywords.contains(n) { throw error("Unexpected '\(n)'") }
                _ = advance(); return .name(n)
            }
        case .op("("):
            _ = advance()
            if isOp(")") { _ = advance(); return .tuple([]) }
            let first = try expression()
            if isName("for") { throw error("Comprehensions arrive in v1.1") }
            if isOp(")") { _ = advance(); return first }
            var items = [first]
            while isOp(",") { _ = advance(); if isOp(")") { break }; items.append(try expression()) }
            try expectOp(")")
            return .tuple(items)
        case .op("["):
            _ = advance()
            var items: [Expr] = []
            while !isOp("]") {
                items.append(try expression())
                if isName("for") { throw error("Comprehensions arrive in v1.1") }
                if !isOp("]") { try expectOp(",") }
            }
            _ = advance()
            return .list(items)
        case .op("{"):
            _ = advance()
            var items: [(Expr, Expr)] = []
            while !isOp("}") {
                let k = try expression()
                try expectOp(":")
                items.append((k, try expression()))
                if !isOp("}") { try expectOp(",") }
            }
            _ = advance()
            return .dict(items)
        case .newline, .eof: throw error("Unexpected end of line")
        case .indent: throw error("Unexpected indent")
        default: throw error("Unexpected token")
        }
    }
}
