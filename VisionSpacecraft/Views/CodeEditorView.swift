import SwiftUI
import FlightCode
import FlightRunner
import SpacecraftCore

/// Text-mode code editor (specs/05): monospaced source, compile status with line, preview summary,
/// craft API reference, Run and Reset to starter.
struct CodeEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(model.mission.id) \(model.mission.title)").font(.title3.bold())
                    Text("Python").font(.caption).padding(.horizontal, 8).padding(.vertical, 3).background(.thinMaterial, in: Capsule())
                    Spacer()
                    Button("Reset to starter", systemImage: "arrow.counterclockwise") { model.resetCode() }
                    Button("Run", systemImage: "play.fill") {
                        Task {
                            await SpaceSwitcher(model: model, open: openSpace, dismiss: dismissSpace).show(.range)
                            model.launch()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                editor
                status
            }
            .padding(20)
            Divider()
            apiReference.frame(width: 300)
        }
    }

    var editor: some View {
        HStack(alignment: .top, spacing: 0) {
            let lines = model.source.components(separatedBy: "\n").count
            let errLine: Int? = { if case let .error(e) = model.compileStatus { return e.line }; return nil }()
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...max(lines, 1), id: \.self) { n in
                            Text("\(n)")
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundStyle(n == errLine ? .red : .secondary)
                                .frame(height: 19.5)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    TextEditor(text: Binding(get: { model.source }, set: { model.source = $0 }))
                        .font(.system(size: 15, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .scrollDisabled(true)
                        .frame(minHeight: CGFloat(lines) * 19.5 + 40)
                }
            }
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch model.compileStatus {
            case .idle: Text("Compiling").foregroundStyle(.secondary)
            case .ok: Label("Compiled", systemImage: "checkmark.circle").foregroundStyle(.green)
            case let .error(e): Label("1 error. Line \(e.line), column \(e.column): \(e.message)", systemImage: "xmark.octagon").foregroundStyle(.red)
            }
            if let p = model.preview, p.compileError == nil {
                if let f = p.result.failure {
                    Text("Preview: \(f.title) at \(String(format: "%.1f", f.time)) s. \(f.body)").foregroundStyle(.orange)
                } else {
                    Text("Preview: mission passed. Apogee \(Int(p.result.apogee)) m, \(String(format: "%.0f", p.result.duration)) s flight.")
                        .foregroundStyle(.green)
                }
                if let fault = p.faults.first { Text("Runtime fault: \(fault)").foregroundStyle(.red) }
            }
            if model.previewing { ProgressView().controlSize(.small) }
            if let err = model.flight.launchError { Text(err).foregroundStyle(.red) }
        }
        .font(.callout)
    }

    var apiReference: some View {
        List {
            Section("Craft API") {
                ForEach(CraftAPIReference.entries, id: \.call) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.call).font(.system(.callout, design: .monospaced))
                        Text(e.doc).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Entry points") {
                Text("setup() runs once before launch.\nupdate(dt) runs 50 times a second, dt = 0.02 s.").font(.caption)
            }
        }
    }
}
