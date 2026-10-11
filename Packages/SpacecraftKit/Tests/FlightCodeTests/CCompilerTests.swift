import Testing
@testable import FlightCode

private final class NoHost: VMHost {
    func craftCall(_ name: String, _ args: [Value]) throws -> Value { .none }
}

private func run(_ src: String, _ fn: String, _ args: [Value] = []) throws -> Value {
    let p = try Compiler.compile(src, language: .c)
    let vm = VM(program: p, host: NoHost())
    try vm.load()
    return try vm.call(fn, args)
}

private func compileError(_ src: String) -> CompileError? {
    do { _ = try CCompiler.compile(src); return nil } catch let e as CompileError { return e } catch { return nil }
}

struct CCompilerTests {
    @Test func intDivisionTruncates() throws {
        let src = "int f(int a, int b) { return a / b; }\nint g(int a, int b) { return a % b; }\ndouble h(int a) { return a / 2.0; }"
        #expect(try run(src, "f", [.int(-7), .int(2)]).asDouble == -3)
        #expect(try run(src, "g", [.int(-7), .int(2)]).asDouble == -1)
        #expect(try run(src, "h", [.int(5)]).asDouble == 2.5)
    }

    @Test func loopsSwitchArraysStructs() throws {
        let src = """
        struct P { double x; int n[3]; };
        int total = 0;
        int sum(int a[], int n) { int s = 0; for (int i = 0; i < n; i++) { if (i == 1) continue; s += a[i]; } return s; }
        int pick(int k) { int r = 0; switch (k) { case 1: r = 10; break; case 2: case 3: r = 20; break; default: r = -1; } return r; }
        int run(void) {
            int a[4] = {1, 2, 3, 4};
            struct P p;
            p.n[2] = 5; p.x = 1.5;
            total = sum(a, 4) + pick(3) + pick(9) + p.n[2];
            int k = 0;
            do { k++; } while (k < 3);
            return total + k;
        }
        """
        #expect(try run(src, "run").asDouble == Double(1 + 3 + 4 + 20 - 1 + 5 + 3))
    }

    @Test func globalsAssignedInFunctionsStayGlobal() throws {
        let src = "int count = 0;\nvoid bump(void) { count = count + 1; }\nint get(void) { bump(); bump(); return count; }"
        #expect(try run(src, "get").asDouble == 2)
    }

    @Test func typeErrors() {
        #expect(compileError("void f(void) { double x = craft_position(); }")?.message.contains("incompatible types") == true)
        #expect(compileError("void f(void) { y = 1; }")?.message.contains("undeclared identifier 'y'") == true)
        #expect(compileError("int f(void) { return; }")?.message.contains("should return a value") == true)
        #expect(compileError("void f(void) { return 1; }")?.message.contains("should not return") == true)
        #expect(compileError("void f(void) { g(); }")?.message.contains("implicit declaration") == true)
        #expect(compileError("int g(int a) { return a; }\nvoid f(void) { g(1, 2); }")?.message.contains("too many arguments") == true)
        #expect(compileError("void f(void) { double v = 1.0; v[0] = 2.0; }")?.message.contains("not an array") == true)
        #expect(compileError("void f(void) { int *p; }")?.message.contains("pointers") == true)
        #expect(compileError("void f(void) { break; }")?.message.contains("not within loop") == true)
        #expect(compileError("void update(int x) {}")?.message.contains("void update(double dt)") == true)
        let e = compileError("void f(void) {\n    double x = ;\n}")
        #expect(e?.line == 2)
        #expect(e?.gccStyle.hasPrefix("2:") == true)
        #expect(e?.message.hasPrefix("error: ") == true)
    }
}
