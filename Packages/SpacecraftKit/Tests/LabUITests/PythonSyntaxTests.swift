import Testing
@testable import LabUI

struct PythonSyntaxTests {
    func kinds(_ s: String) -> [(String, SyntaxKind)] { PythonSyntax.runs(s).filter { $0.kind != .plain }.map { ($0.text, $0.kind) } }

    @Test func defAndParams() {
        let k = kinds("def steer(craft, goal):")
        #expect(k.first(where: { $0.0 == "def" })?.1 == .keyword)
        #expect(k.first(where: { $0.0 == "steer" })?.1 == .function)
        #expect(k.first(where: { $0.0 == "goal" })?.1 == .variable)
    }

    @Test func craftCallsAndNumbers() {
        let k = kinds("    craft.set_pitch(KP * err + 0.5)")
        #expect(k.first(where: { $0.0 == "craft" })?.1 == .builtin)
        #expect(k.first(where: { $0.0 == "set_pitch" })?.1 == .function)
        #expect(k.first(where: { $0.0 == "0.5" })?.1 == .number)
        #expect(k.first(where: { $0.0 == "KP" })?.1 == .variable)
    }

    @Test func commentsAndStringsWin() {
        let k = kinds("state[\"phase\"] = \"coast\"  # next: drogue")
        #expect(k.last?.1 == .comment && k.last?.0 == "# next: drogue")
        #expect(k.filter { $0.1 == .string }.count == 2)
        #expect(!k.contains { $0.0 == "next" })
    }

    @Test func attributeAfterDotAndConstants() {
        let k = kinds("x = math.pi if True else None")
        #expect(k.first(where: { $0.0 == "pi" })?.1 == .variable)
        #expect(k.first(where: { $0.0 == "True" })?.1 == .number)
        #expect(k.first(where: { $0.0 == "if" })?.1 == .keyword)
    }

    @Test func roundTripsText() {
        for line in ["    pid[\"integral\"] = math.clamp(pid[\"integral\"] + err * dt, -I_LIMIT, I_LIMIT)", "while a > math.pi:", "# only a comment", ""] {
            #expect(PythonSyntax.runs(line).map(\.text).joined() == line)
        }
    }
}
