import SwiftUI
import Curriculum

// MARK: - Layout and shape

/// Wraps its children onto lines, like words in a sentence.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? .infinity, subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = arrange(bounds.width, subviews)
        for (i, f) in r.frames.enumerated() { subviews[i].place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), proposal: ProposedViewSize(f.size)) }
    }
    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = [], x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxW: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > width { x = 0; y += rowH + lineSpacing; rowH = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height); maxW = max(maxW, x - spacing)
        }
        return (frames, CGSize(width: maxW, height: y + rowH))
    }
}

/// A puzzle-piece rectangle: a notch cut into the top edge and a bump on the bottom edge.
struct BlockShape: Shape {
    var tl: CGFloat = 8, tr: CGFloat = 8, br: CGFloat = 8, bl: CGFloat = 8
    var topNotch = true
    var bottomBump = true
    static let notchX: CGFloat = 16, notchW: CGFloat = 30, notchH: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height - (bottomBump ? Self.notchH : 0)
        let nx = Self.notchX, nw = Self.notchW, nh = Self.notchH
        var p = Path()
        p.move(to: CGPoint(x: tl, y: 0))
        if topNotch {
            p.addLine(to: CGPoint(x: nx, y: 0)); p.addLine(to: CGPoint(x: nx + 4, y: nh))
            p.addLine(to: CGPoint(x: nx + nw - 4, y: nh)); p.addLine(to: CGPoint(x: nx + nw, y: 0))
        }
        p.addLine(to: CGPoint(x: w - tr, y: 0))
        if tr > 0 { p.addRelativeArc(center: CGPoint(x: w - tr, y: tr), radius: tr, startAngle: .degrees(-90), delta: .degrees(90)) }
        p.addLine(to: CGPoint(x: w, y: h - br))
        if br > 0 { p.addRelativeArc(center: CGPoint(x: w - br, y: h - br), radius: br, startAngle: .degrees(0), delta: .degrees(90)) }
        if bottomBump {
            p.addLine(to: CGPoint(x: nx + nw, y: h)); p.addLine(to: CGPoint(x: nx + nw - 4, y: h + nh))
            p.addLine(to: CGPoint(x: nx + 4, y: h + nh)); p.addLine(to: CGPoint(x: nx, y: h))
        }
        p.addLine(to: CGPoint(x: bl, y: h))
        if bl > 0 { p.addRelativeArc(center: CGPoint(x: bl, y: h - bl), radius: bl, startAngle: .degrees(90), delta: .degrees(90)) }
        p.addLine(to: CGPoint(x: 0, y: tl))
        if tl > 0 { p.addRelativeArc(center: CGPoint(x: tl, y: tl), radius: tl, startAngle: .degrees(180), delta: .degrees(90)) }
        p.closeSubpath()
        return p
    }
}

// MARK: - Block pieces

struct BlockPlate: ViewModifier {
    var category: BlockCategory
    var shape: BlockShape
    var lit = false
    func body(content: Content) -> some View {
        content
            .background {
                shape.fill(LinearGradient(colors: [Lab.blockFill(category), Lab.blockFill(category).opacity(0.92)], startPoint: .top, endPoint: .bottom))
                shape.stroke(Lab.blockEdge(category), lineWidth: 1)
            }
            .overlay { if lit { shape.stroke(.white, lineWidth: 3).shadow(color: Lab.blockGlow(category), radius: 14) } }
            .shadow(color: lit ? Lab.blockGlow(category).opacity(0.8) : .clear, radius: 12)
    }
}

struct BlockPartView: View {
    var part: BlockPart
    var knobs: [String: BlockKnob]
    @Binding var values: [String: Double]

    var body: some View {
        switch part {
        case let .text(t):
            Text(t).font(Lab.soft(14)).foregroundStyle(.white).shadow(color: .black.opacity(0.2), radius: 0, y: 1)
        case let .variable(v):
            Text(v).font(Lab.soft(13)).foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 2)
                .background(Capsule().fill(Lab.variablePill)).overlay(Capsule().stroke(Color(hue: 12 / 360, saturation: 0.8, brightness: 0.55), lineWidth: 1))
        case let .reporter(r):
            Text(r).font(Lab.soft(13)).italic().foregroundStyle(Color(red: 0.16, green: 0.19, blue: 0.42)).padding(.horizontal, 10).padding(.vertical, 2)
                .background(Capsule().fill(Color(red: 0.93, green: 0.94, blue: 1)))
        case let .input(key):
            if let k = knobs[key] { KnobField(knob: k, value: Binding(get: { values[key] ?? k.value }, set: { values[key] = $0 })) }
        }
    }
}

/// A white numeric pill. Typing is clamped to the knob's range when committed.
struct KnobField: View {
    var knob: BlockKnob
    @Binding var value: Double
    var body: some View {
        HStack(spacing: 3) {
            Button { value = max(knob.min, value - knob.step) } label: { Image(systemName: "minus").font(.system(size: 11, weight: .bold)) }
                .buttonStyle(.plain).foregroundStyle(Color(red: 0.11, green: 0.14, blue: 0.33)).frame(width: 22, height: 22).contentShape(Rectangle())
                .accessibilityLabel("Decrease \(knob.label)")
            TextField("", value: Binding(get: { value }, set: { value = min(max($0, knob.min), knob.max) }), format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.center)
                #if os(visionOS)
                .keyboardType(.decimalPad)
                #endif
                .font(Lab.mono(13).weight(.bold))
                .foregroundStyle(Color(red: 0.11, green: 0.14, blue: 0.33))
                .frame(width: 56)
                .textFieldStyle(.plain)
            Button { value = min(knob.max, value + knob.step) } label: { Image(systemName: "plus").font(.system(size: 11, weight: .bold)) }
                .buttonStyle(.plain).foregroundStyle(Color(red: 0.11, green: 0.14, blue: 0.33)).frame(width: 22, height: 22).contentShape(Rectangle())
                .accessibilityLabel("Increase \(knob.label)")
        }
        .padding(.horizontal, 9).padding(.vertical, 2)
        .background(Capsule().fill(.white))
        .accessibilityLabel(knob.label)
    }
}

/// Does `node` (or one of its kids) cover `line`, and is no kid more specific?
private func isInnermost(_ node: BlockNode, _ line: Int) -> Bool {
    guard (node.firstLine...node.lastLine).contains(line) else { return false }
    return !node.kids.contains { (($0.firstLine...$0.lastLine).contains(line)) }
}

struct BlockNodeView: View {
    var node: BlockNode
    var knobs: [String: BlockKnob]
    @Binding var values: [String: Double]
    /// Line of the owning spec that is executing, to light the innermost block.
    var litLine: Int?
    var isLast = false

    var body: some View {
        let lit = litLine.map { isInnermost(node, $0) } ?? false
        if node.isC { cBlock(lit: lit) } else { stack(lit: lit) }
    }

    private func sentence() -> some View {
        FlowLayout { ForEach(Array(node.parts.enumerated()), id: \.offset) { _, p in BlockPartView(part: p, knobs: knobs, values: $values) } }
    }

    private func stack(lit: Bool) -> some View {
        sentence().padding(.horizontal, 13).padding(.top, 8).padding(.bottom, 8 + BlockShape.notchH)
            .frame(minHeight: 40 + BlockShape.notchH, alignment: .leading)
            .modifier(BlockPlate(category: node.category, shape: BlockShape(), lit: lit))
            .fixedSize()
    }

    private func cBlock(lit: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sentence().padding(.horizontal, 13).padding(.vertical, 8).frame(minHeight: 40, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(BlockPlate(category: node.category, shape: BlockShape(tl: 8, tr: 8, br: 0, bl: 0, topNotch: true, bottomBump: false), lit: lit))
            HStack(alignment: .top, spacing: 0) {
                Rectangle().fill(Lab.blockFill(node.category)).frame(width: 18)
                    .overlay(alignment: .trailing) { Rectangle().fill(Lab.blockEdge(node.category)).frame(width: 1) }
                VStack(alignment: .leading, spacing: -BlockShape.notchH) {
                    ForEach(Array(node.kids.enumerated()), id: \.offset) { _, k in BlockNodeView(node: k, knobs: knobs, values: $values, litLine: litLine) }
                }
                .padding(.top, 0).padding(.bottom, node.kids.isEmpty ? 24 : 0)
                .frame(minWidth: 220, alignment: .leading)
            }
            .background(Color.black.opacity(0.22))
            Color.clear.frame(height: 20 + BlockShape.notchH)
                .modifier(BlockPlate(category: node.category, shape: BlockShape(tl: 0, tr: 0, br: 8, bl: 8, topNotch: false, bottomBump: true)))
        }
        .fixedSize()
    }
}

// MARK: - Composer

/// The block workspace: a palette to pick from and a script to arrange, with tunable inputs inside the blocks.
public struct BlockComposer: View {
    public var program: BlockProgram
    @Binding public var order: [String]
    @Binding public var values: [String: Double]
    /// Block whose code raised an error; drawn with a red outline.
    public var errorBlockID: String?
    /// While tracing, the source line that runs now. The innermost matching block lights up.
    public var lit: LineOrigin?
    /// Hide editing affordances (used beside the trace).
    public var readOnly = false

    public init(program: BlockProgram, order: Binding<[String]>, values: Binding<[String: Double]>, errorBlockID: String? = nil, lit: LineOrigin? = nil, readOnly: Bool = false) {
        self.program = program; _order = order; _values = values; self.errorBlockID = errorBlockID; self.lit = lit; self.readOnly = readOnly
    }

    @State private var contentHeight: CGFloat = 0

    private var knobs: [String: BlockKnob] { Dictionary(uniqueKeysWithValues: program.knobs.map { ($0.key, $0) }) }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !readOnly { palette.frame(width: 156) }
            script
        }
    }

    private var palette: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                HStack { Text("BLOCKS").font(Lab.label(10)).tracking(1.4).foregroundStyle(Lab.muted); Spacer()
                    Button("Clear") { order = []; values = program.startingValues }.font(Lab.soft(11)).buttonStyle(.plain).foregroundStyle(Lab.muted)
                }
                ForEach(program.specs) { s in
                    Button { order.append(s.id) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(Lab.soft(13)).foregroundStyle(.white)
                            if s.isDistractor { Text("TRY ME").font(Lab.label(9)).tracking(1).foregroundStyle(.white.opacity(0.8)) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 10)
                        .modifier(BlockPlate(category: s.category, shape: BlockShape(bottomBump: false)))
                    }
                    .buttonStyle(.plain)
                    .lift()
                    .draggable("palette:\(s.id)")
                    .accessibilityHint(s.summary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var script: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: -BlockShape.notchH) {
                hat
                ForEach(Array(order.enumerated()), id: \.offset) { i, id in
                    if let spec = program.spec(id) { group(spec, index: i) }
                }
                Color.clear.frame(height: 60).dropDestination(for: String.self) { items, _ in drop(items, at: order.count) }
                    .overlay(alignment: .topLeading) {
                        if order.isEmpty { Text("Tap or drag blocks here").font(Lab.soft(13)).foregroundStyle(Lab.faint).padding(.top, 20) }
                    }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { contentHeight = $0 }
        }
        .frame(maxHeight: readOnly && contentHeight > 0 ? contentHeight : .infinity)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(red: 0.02, green: 0.025, blue: 0.12).opacity(0.7))
            Canvas { ctx, size in
                var dots = Path(); var y: CGFloat = 11
                while y < size.height { var x: CGFloat = 11; while x < size.width { dots.addEllipse(in: CGRect(x: x, y: y, width: 1.6, height: 1.6)); x += 22 }; y += 22 }
                ctx.fill(dots, with: .color(Lab.edge.opacity(0.18)))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Lab.edge.opacity(0.22), lineWidth: 1) }
    }

    private var hat: some View {
        HStack(spacing: 8) {
            Text("when flying").font(Lab.soft(14)).foregroundStyle(.white)
            Text("every 0.02 s").font(Lab.soft(13)).italic().foregroundStyle(Color(red: 0.16, green: 0.19, blue: 0.42)).padding(.horizontal, 10).padding(.vertical, 2).background(Capsule().fill(Color(red: 0.93, green: 0.94, blue: 1)))
            Text("do").font(Lab.soft(14)).foregroundStyle(.white)
        }
        .padding(.horizontal, 14).padding(.top, 16).padding(.bottom, 8 + BlockShape.notchH)
        .modifier(BlockPlate(category: .event, shape: BlockShape(tl: 30, tr: 30, br: 8, bl: 8, topNotch: false, bottomBump: true)))
        .padding(.bottom, 0)
    }

    private func group(_ spec: BlockSpec, index: Int) -> some View {
        VStack(alignment: .leading, spacing: -BlockShape.notchH) {
            ForEach(Array(spec.nodes.enumerated()), id: \.offset) { _, n in
                BlockNodeView(node: n, knobs: knobs, values: $values, litLine: lit?.blockID == spec.id ? lit?.line : nil)
            }
        }
        .overlay { if errorBlockID == spec.id { RoundedRectangle(cornerRadius: 8).stroke(Lab.danger, lineWidth: 2).padding(-3) } }
        .overlay(alignment: .topTrailing) {
            if !readOnly {
                Button { order.remove(at: index) } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(.white.opacity(0.75)) }
                    .buttonStyle(.plain).offset(x: 22, y: 4).accessibilityLabel("Remove \(spec.name)")
            }
        }
        .padding(.trailing, readOnly ? 0 : 0)
        .draggable("stack:\(index)")
        .dropDestination(for: String.self) { items, _ in drop(items, at: index) }
        .contextMenu {
            if !readOnly {
                Button("Move up", systemImage: "arrow.up") { move(index, by: -1) }.disabled(index == 0)
                Button("Move down", systemImage: "arrow.down") { move(index, by: 1) }.disabled(index == order.count - 1)
                Button("Remove", systemImage: "trash", role: .destructive) { order.remove(at: index) }
            }
        }
    }

    private func move(_ i: Int, by d: Int) { let j = i + d; guard order.indices.contains(j) else { return }; order.swapAt(i, j) }

    private func drop(_ items: [String], at index: Int) -> Bool {
        guard !readOnly, let item = items.first else { return false }
        let parts = item.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return false }
        if parts[0] == "palette", program.spec(parts[1]) != nil { order.insert(parts[1], at: min(index, order.count)); return true }
        if parts[0] == "stack", let from = Int(parts[1]), order.indices.contains(from) {
            let id = order.remove(at: from)
            order.insert(id, at: from < index ? max(index - 1, 0) : index)
            return true
        }
        return false
    }
}

public extension View {
    /// visionOS hover feedback; a no-op elsewhere so the package also builds and tests on macOS.
    @ViewBuilder func lift() -> some View {
        #if os(visionOS)
        hoverEffect(.lift)
        #else
        self
        #endif
    }
}
