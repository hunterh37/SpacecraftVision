import Foundation

public struct CompileError: Error, Sendable, Hashable, CustomStringConvertible {
    public var line: Int
    public var column: Int
    public var message: String
    public init(_ message: String, line: Int, column: Int = 1) { self.message = message; self.line = line; self.column = column }
    public var description: String { "line \(line):\(column): \(message)" }
}

enum Tok: Equatable {
    case name(String)
    case int(Int)
    case float(Double)
    case string(String)
    case op(String)
    case newline, indent, dedent, eof
}

struct Token {
    var tok: Tok
    var line: Int
    var col: Int
}

/// Python-subset tokenizer with INDENT/DEDENT and implicit line joining inside brackets.
struct Lexer {
    static let keywords: Set<String> = ["def", "if", "elif", "else", "while", "for", "in", "return", "break", "continue",
                                        "pass", "and", "or", "not", "is", "True", "False", "None", "import", "global",
                                        "class", "try", "lambda", "from", "with", "yield"]
    static let ops3 = ["**=", "//="]
    static let ops2 = ["**", "//", "==", "!=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "->"]
    static let ops1 = Set("+-*/%<>=()[]{},:.;")

    static func tokenize(_ source: String) throws -> [Token] {
        var out: [Token] = []
        var indents = [0]
        var depth = 0
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\t", with: "    ")
            .components(separatedBy: "\n")
        for (li, raw) in lines.enumerated() {
            let lineNo = li + 1
            let chars = Array(raw)
            var i = 0
            if depth == 0 {
                var col = 0
                while i < chars.count, chars[i] == " " { col += 1; i += 1 }
                if i >= chars.count || chars[i] == "#" { continue }
                if col > indents.last! {
                    indents.append(col); out.append(Token(tok: .indent, line: lineNo, col: 1))
                } else {
                    while col < indents.last! {
                        indents.removeLast(); out.append(Token(tok: .dedent, line: lineNo, col: 1))
                    }
                    if col != indents.last! { throw CompileError("Indentation does not match any outer level", line: lineNo, column: col + 1) }
                }
            }
            var emitted = false
            while i < chars.count {
                let c = chars[i]
                let col = i + 1
                if c == " " { i += 1; continue }
                if c == "#" { break }
                if c == "\\" && i == chars.count - 1 { i += 1; continue }
                if c.isLetter || c == "_" {
                    var j = i
                    while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                    out.append(Token(tok: .name(String(chars[i..<j])), line: lineNo, col: col)); i = j; emitted = true; continue
                }
                if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
                    var j = i, isFloat = false
                    while j < chars.count, chars[j].isNumber || chars[j] == "." || chars[j] == "_" ||
                            ((chars[j] == "e" || chars[j] == "E") && j + 1 < chars.count) ||
                            ((chars[j] == "-" || chars[j] == "+") && j > i && (chars[j - 1] == "e" || chars[j - 1] == "E")) {
                        if chars[j] == "." || chars[j] == "e" || chars[j] == "E" { isFloat = true }
                        j += 1
                    }
                    let text = String(chars[i..<j]).replacingOccurrences(of: "_", with: "")
                    if isFloat {
                        guard let v = Double(text) else { throw CompileError("Bad number \(text)", line: lineNo, column: col) }
                        out.append(Token(tok: .float(v), line: lineNo, col: col))
                    } else {
                        guard let v = Int(text) else { throw CompileError("Bad number \(text)", line: lineNo, column: col) }
                        out.append(Token(tok: .int(v), line: lineNo, col: col))
                    }
                    i = j; emitted = true; continue
                }
                if c == "\"" || c == "'" {
                    var j = i + 1, s = ""
                    while j < chars.count, chars[j] != c {
                        if chars[j] == "\\", j + 1 < chars.count {
                            j += 1
                            switch chars[j] { case "n": s.append("\n"); case "t": s.append("\t"); default: s.append(chars[j]) }
                        } else { s.append(chars[j]) }
                        j += 1
                    }
                    if j >= chars.count { throw CompileError("Unterminated string", line: lineNo, column: col) }
                    out.append(Token(tok: .string(s), line: lineNo, col: col)); i = j + 1; emitted = true; continue
                }
                let rest = String(chars[i..<min(i + 3, chars.count)])
                if let op = ops3.first(where: { rest.hasPrefix($0) }) ?? ops2.first(where: { rest.hasPrefix($0) }) {
                    out.append(Token(tok: .op(op), line: lineNo, col: col)); i += op.count; emitted = true; continue
                }
                if ops1.contains(c) {
                    if "([{".contains(c) { depth += 1 }
                    if ")]}".contains(c) { depth = max(0, depth - 1) }
                    out.append(Token(tok: .op(String(c)), line: lineNo, col: col)); i += 1; emitted = true; continue
                }
                if c == "!" { throw CompileError("Unexpected '!'; use 'not'", line: lineNo, column: col) }
                throw CompileError("Unexpected character '\(c)'", line: lineNo, column: col)
            }
            let continued = raw.trimmingCharacters(in: .whitespaces).hasSuffix("\\")
            if emitted && depth == 0 && !continued { out.append(Token(tok: .newline, line: lineNo, col: chars.count + 1)) }
        }
        let last = lines.count
        if out.last.map({ $0.tok != .newline }) ?? false { out.append(Token(tok: .newline, line: last, col: 1)) }
        while indents.count > 1 { indents.removeLast(); out.append(Token(tok: .dedent, line: last, col: 1)) }
        out.append(Token(tok: .eof, line: last, col: 1))
        return out
    }
}
