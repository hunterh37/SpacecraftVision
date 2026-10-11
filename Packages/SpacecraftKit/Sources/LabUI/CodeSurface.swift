import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
#endif

extension Lab {
    static func monoLineHeight(_ size: CGFloat) -> CGFloat {
        let f = PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #if canImport(UIKit)
        return ceil(f.lineHeight)
        #else
        return ceil(f.ascender - f.descender + f.leading)
        #endif
    }
}

/// Read-only, syntax coloured code with a gutter. Lines can be lit (hover link to blocks), marked current (trace),
/// badged with a visit count (loops), or flagged with an error and a VS Code style popup.
public struct CodeSurface: View {
    public var source: String
    public var currentLine: Int?
    public var litLines: Set<Int>
    public var visits: [Int: Int]
    public var errorLine: Int?
    public var errorText: String?
    public var fontSize: CGFloat
    public var onHover: ((Int?) -> Void)?

    public init(source: String, currentLine: Int? = nil, litLines: Set<Int> = [], visits: [Int: Int] = [:], errorLine: Int? = nil, errorText: String? = nil,
                fontSize: CGFloat = 14, onHover: ((Int?) -> Void)? = nil) {
        self.source = source; self.currentLine = currentLine; self.litLines = litLines; self.visits = visits
        self.errorLine = errorLine; self.errorText = errorText; self.fontSize = fontSize; self.onHover = onHover
    }

    public var body: some View {
        let lines = source.components(separatedBy: "\n")
        let lh = Lab.monoLineHeight(fontSize)
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                        row(n: i + 1, line: line, height: lh)
                            .id(i + 1)
                            .zIndex(errorLine == i + 1 ? 1 : 0)
                    }
                }
                .padding(.vertical, 12)
                .padding(.bottom, errorLine == nil ? 0 : 70)
            }
            .onChange(of: currentLine) { _, new in if let new { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(new, anchor: .center) } } }
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.13).opacity(0.86), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Lab.edge.opacity(0.22), lineWidth: 1) }
    }

    @ViewBuilder private func row(n: Int, line: String, height: CGFloat) -> some View {
        let isCurrent = currentLine == n, isLit = litLines.contains(n), isErr = errorLine == n
        HStack(spacing: 14) {
            Text("\(n)").font(Lab.mono(fontSize)).foregroundStyle(isErr ? Lab.danger : isCurrent ? Lab.gold : Lab.faint)
                .frame(width: 34, alignment: .trailing)
            Text(PythonSyntax.attributed(line.isEmpty ? " " : line, size: fontSize)).font(Lab.mono(fontSize)).fixedSize()
                .underline(isErr, color: Lab.danger)
            Spacer(minLength: 24)
            if let c = visits[n], c > 1 {
                Text("×\(c)").font(Lab.mono(fontSize - 3).weight(.semibold)).foregroundStyle(Lab.navy)
                    .padding(.horizontal, 7).background(Lab.teal.opacity(0.85), in: Capsule())
            }
        }
        .frame(height: height)
        .padding(.trailing, 10)
        .background {
            if isCurrent { LinearGradient(colors: [Lab.gold.opacity(0.30), Lab.gold.opacity(0.04)], startPoint: .leading, endPoint: .trailing) }
            else if isLit { LinearGradient(colors: [Lab.teal.opacity(0.22), Lab.teal.opacity(0.03)], startPoint: .leading, endPoint: .trailing) }
            else if isErr { Lab.danger.opacity(0.12) }
        }
        .overlay(alignment: .leading) { if isCurrent || isLit { Rectangle().fill(isCurrent ? Lab.gold : Lab.teal).frame(width: 3) } }
        .overlay(alignment: .topLeading) { if isErr, let t = errorText { ErrorPopup(text: t).offset(x: 52, y: height + 4) } }
        .contentShape(Rectangle())
        .onHover { inside in onHover?(inside ? n : nil) }
    }
}

/// The hover card from the editor: message, source, and the two actions.
struct ErrorPopup: View {
    var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(text).font(Lab.mono(13)).foregroundStyle(Lab.ink).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                Text("python").font(Lab.mono(12)).foregroundStyle(Lab.faint)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            Divider().overlay(Lab.edge.opacity(0.2))
            HStack(spacing: 16) {
                Text("View Problem").foregroundStyle(Color(red: 0.55, green: 0.77, blue: 1))
                Text("Quick Fix...").foregroundStyle(Color(red: 0.55, green: 0.77, blue: 1))
            }
            .font(Lab.mono(12)).padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color(red: 0.15, green: 0.19, blue: 0.33))
        }
        .frame(maxWidth: 420, alignment: .leading)
        .background(Color(red: 0.11, green: 0.14, blue: 0.26), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Lab.edge.opacity(0.35), lineWidth: 1) }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
    }
}

/// Editable Python with live colour. A transparent `TextEditor` sits over the coloured copy; both share one
/// font and a fixed line height so glyphs line up.
public struct PythonEditor: View {
    @Binding public var text: String
    public var errorLine: Int?
    public var errorText: String?
    public var fontSize: CGFloat = 14
    public init(text: Binding<String>, errorLine: Int? = nil, errorText: String? = nil, fontSize: CGFloat = 14) {
        _text = text; self.errorLine = errorLine; self.errorText = errorText; self.fontSize = fontSize
    }

    public var body: some View {
        let lines = text.components(separatedBy: "\n")
        let lh = Lab.monoLineHeight(fontSize)
        ScrollView {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(lines.indices), id: \.self) { i in
                        Text("\(i + 1)").font(Lab.mono(fontSize)).foregroundStyle(errorLine == i + 1 ? Lab.danger : Lab.faint).frame(height: lh)
                    }
                }
                .frame(width: 40).padding(.top, 12)
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.indices), id: \.self) { i in
                            Color.clear.frame(height: lh)
                                .background(errorLine == i + 1 ? Lab.danger.opacity(0.12) : .clear)
                        }
                    }
                    .padding(.top, 12)
                    .allowsHitTesting(false)
                    #if canImport(UIKit)
                    CodeTextView(text: $text, fontSize: fontSize, lineHeight: lh, errorLine: errorLine)
                        .frame(minWidth: 320, minHeight: CGFloat(lines.count) * lh + 28, alignment: .topLeading)
                    #else
                    TextEditor(text: $text)
                        .font(Lab.mono(fontSize))
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .autocorrectionDisabled()
                        .frame(minWidth: 320, minHeight: CGFloat(lines.count) * lh + 28)
                    #endif
                    if let l = errorLine, let t = errorText {
                        ErrorPopup(text: t).offset(x: 12, y: 12 + CGFloat(l) * lh + 4).allowsHitTesting(false)
                    }
                }
            }
            .padding(.bottom, errorLine == nil ? 0 : 90)
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.13).opacity(0.86), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Lab.edge.opacity(0.22), lineWidth: 1) }
    }
}

#if canImport(UIKit)
/// UITextView that colours its own text storage, so the caret and the glyphs are the same text.
/// Insets match the gutter: 12 pt top, 12 pt leading, no line fragment padding, fixed line height, no wrap.
struct CodeTextView: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var lineHeight: CGFloat
    var errorLine: Int?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let v = UITextView()
        v.backgroundColor = .clear
        v.isScrollEnabled = false
        v.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 16, right: 12)
        v.textContainer.lineFragmentPadding = 0
        v.textContainer.widthTracksTextView = false
        v.textContainer.size = CGSize(width: 10_000, height: CGFloat.greatestFiniteMagnitude)
        v.textContainer.lineBreakMode = .byClipping
        v.autocorrectionType = .no
        v.autocapitalizationType = .none
        v.spellCheckingType = .no
        v.smartQuotesType = .no
        v.smartDashesType = .no
        v.smartInsertDeleteType = .no
        v.keyboardType = .asciiCapable
        v.tintColor = .white
        v.delegate = context.coordinator
        context.coordinator.apply(text, to: v)
        return v
    }

    func updateUIView(_ v: UITextView, context: Context) {
        context.coordinator.parent = self
        if v.text != text { context.coordinator.apply(text, to: v) }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let rows = CGFloat(text.components(separatedBy: "\n").count)
        let longest = text.components(separatedBy: "\n").map(\.count).max() ?? 0
        let charW = ("M" as NSString).size(withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)]).width
        let w = max(proposal.width ?? 320, CGFloat(longest + 4) * charW + 24)
        return CGSize(width: w, height: rows * lineHeight + 28)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeTextView
        init(_ p: CodeTextView) { parent = p }

        func attributed(_ s: String) -> NSAttributedString {
            let font = UIFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
            let para = NSMutableParagraphStyle()
            para.minimumLineHeight = parent.lineHeight; para.maximumLineHeight = parent.lineHeight
            let out = NSMutableAttributedString()
            let lines = s.components(separatedBy: "\n")
            for (i, line) in lines.enumerated() {
                for r in PythonSyntax.runs(line) {
                    var a: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: para, .foregroundColor: UIColor(PythonSyntax.color(r.kind))]
                    if r.kind == .comment, let d = font.fontDescriptor.withSymbolicTraits(.traitItalic) { a[.font] = UIFont(descriptor: d, size: parent.fontSize) }
                    if parent.errorLine == i + 1 { a[.underlineStyle] = NSUnderlineStyle.single.rawValue; a[.underlineColor] = UIColor(Lab.danger) }
                    out.append(NSAttributedString(string: r.text, attributes: a))
                }
                if i < lines.count - 1 { out.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: para])) }
            }
            return out
        }

        func typing() -> [NSAttributedString.Key: Any] {
            let para = NSMutableParagraphStyle()
            para.minimumLineHeight = parent.lineHeight; para.maximumLineHeight = parent.lineHeight
            return [.font: UIFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular), .paragraphStyle: para, .foregroundColor: UIColor(Lab.Syntax.plain)]
        }

        func apply(_ s: String, to v: UITextView) {
            let sel = v.selectedRange
            v.attributedText = attributed(s)
            v.typingAttributes = typing()
            let n = (s as NSString).length
            v.selectedRange = NSRange(location: min(sel.location, n), length: min(sel.length, max(0, n - min(sel.location, n))))
        }

        func textView(_ v: UITextView, shouldChangeTextIn range: NSRange, replacementText t: String) -> Bool {
            if t == "\t" { v.insertText("    "); return false }
            if t == "\n" {
                let ns = v.text as NSString
                let lineStart = ns.lineRange(for: NSRange(location: range.location, length: 0)).location
                let line = ns.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
                var indent = String(line.prefix { $0 == " " })
                if line.trimmingCharacters(in: .whitespaces).hasSuffix(":") { indent += "    " }
                v.insertText("\n" + indent); return false
            }
            return true
        }

        func textViewDidChange(_ v: UITextView) {
            guard v.markedTextRange == nil else { return }
            let s = v.text ?? ""
            apply(s, to: v)
            if parent.text != s { parent.text = s }
        }
    }
}
#endif
