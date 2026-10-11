import SwiftUI

public enum SyntaxKind: Sendable, Hashable { case keyword, function, number, string, variable, builtin, punct, op, comment, plain }

public struct SyntaxRun: Sendable, Hashable {
    public var text: String
    public var kind: SyntaxKind
}

/// A small tokenizer for the Python subset the VM runs. Line based, no multi-line strings (the subset has none).
public enum PythonSyntax {
    static let keywords: Set<String> = ["def", "return", "for", "in", "if", "elif", "else", "import", "from", "while", "and", "or", "not", "continue", "break", "pass", "is", "as"]
    static let constants: Set<String> = ["True", "False", "None"]
    static let builtins: Set<String> = ["abs", "min", "max", "len", "range", "int", "float", "round", "str", "craft", "math"]

    public static func runs(_ line: String) -> [SyntaxRun] {
        var out: [SyntaxRun] = []
        let chars = Array(line)
        var i = 0
        var previousWord = ""
        var afterDot = false
        func push(_ s: String, _ k: SyntaxKind) { if !s.isEmpty { out.append(SyntaxRun(text: s, kind: k)) } }
        func nextNonSpace(_ from: Int) -> Character? { var j = from; while j < chars.count, chars[j] == " " { j += 1 }; return j < chars.count ? chars[j] : nil }
        while i < chars.count {
            let c = chars[i]
            if c == "#" { push(String(chars[i...]), .comment); break }
            if c == "\"" || c == "'" {
                var j = i + 1
                while j < chars.count, chars[j] != c { if chars[j] == "\\" { j += 1 }; j += 1 }
                let end = min(j + 1, chars.count)
                push(String(chars[i..<end]), .string); i = end; previousWord = ""; afterDot = false; continue
            }
            if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber && !afterDot) {
                var j = i
                while j < chars.count, chars[j].isNumber || chars[j] == "." || chars[j] == "e" && j + 1 < chars.count && (chars[j + 1].isNumber || chars[j + 1] == "-") { j += 1 }
                push(String(chars[i..<j]), .number); i = j; previousWord = ""; afterDot = false; continue
            }
            if c.isLetter || c == "_" {
                var j = i
                while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                let w = String(chars[i..<j]), call = nextNonSpace(j) == "("
                let kind: SyntaxKind
                if keywords.contains(w) { kind = .keyword }
                else if constants.contains(w) { kind = .number }
                else if previousWord == "def" { kind = .function }
                else if afterDot { kind = call ? .function : .variable }
                else if builtins.contains(w) { kind = call || w == "craft" || w == "math" ? .builtin : .variable }
                else if call { kind = .function }
                else { kind = .variable }
                push(w, kind); i = j; previousWord = w; afterDot = false; continue
            }
            if c == " " || c == "\t" { push(String(c), .plain); i += 1; continue }
            if "()[]{}".contains(c) { push(String(c), .punct); i += 1; previousWord = ""; afterDot = false; continue }
            // operators and separators: group a run
            var j = i
            while j < chars.count, "+-*/%<>=!,:.&|".contains(chars[j]) { j += 1 }
            if j == i { push(String(c), .plain); i += 1; continue }
            let opText = String(chars[i..<j])
            push(opText, .op); i = j; previousWord = ""; afterDot = opText == "."
        }
        return out
    }

    public static func color(_ k: SyntaxKind) -> Color {
        switch k {
        case .keyword: Lab.Syntax.keyword; case .function: Lab.Syntax.function; case .number: Lab.Syntax.number; case .string: Lab.Syntax.string
        case .variable: Lab.Syntax.variable; case .builtin: Lab.Syntax.builtin; case .punct: Lab.Syntax.punct; case .op: Lab.Syntax.op
        case .comment: Lab.Syntax.comment; case .plain: Lab.Syntax.plain
        }
    }

    public static func attributed(_ line: String, size: CGFloat = 14) -> AttributedString {
        var result = AttributedString()
        for r in runs(line) {
            var piece = AttributedString(r.text)
            piece.foregroundColor = color(r.kind)
            if r.kind == .comment { piece.font = Lab.mono(size).italic() }
            result.append(piece)
        }
        return result
    }
}
