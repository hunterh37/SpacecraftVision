import Testing
@testable import FlightCode

final class LogHost: VMHost {
    var log: [String] = []
    var calls: [String] = []
    func craftCall(_ name: String, _ args: [Value]) throws -> Value {
        calls.append(name)
        switch name {
        case "log": log.append(args.first?.repr ?? ""); return .none
        case "altitude": return .float(100)
        case "attitude": return .tuple([.float(1.0), .float(0.5), .float(0)])
        default: return .none
        }
    }
}

func run(_ src: String, _ fn: String = "main") throws -> (Value, LogHost) {
    let host = LogHost()
    let vm = VM(program: try Compiler.compile(src), host: host)
    try vm.load()
    return (try vm.call(fn, []), host)
}

func int(_ v: Value) -> Int? { if case let .int(i) = v { return i }; return nil }
func dbl(_ v: Value) -> Double? { v.asDouble }

struct VMTests {
    @Test func arithmeticAndPrecedence() throws {
        let (v, _) = try run("def main():\n    return 2 + 3 * 4 ** 2 // 5 - -1\n")
        #expect(int(v) == 2 + (3 * 16) / 5 + 1)
    }
    @Test func pythonModAndFloorDiv() throws {
        #expect(int(try run("def main():\n    return -7 // 2\n").0) == -4)
        #expect(int(try run("def main():\n    return -7 % 3\n").0) == 2)
        #expect(dbl(try run("def main():\n    return 7 / 2\n").0) == 3.5)
    }
    @Test func loopsAndControl() throws {
        let src = """
        def main():
            total = 0
            for i in range(10):
                if i == 3:
                    continue
                if i == 8:
                    break
                total += i
            n = 0
            while True:
                n += 1
                if n >= 5:
                    break
            return total * 100 + n
        """
        #expect(int(try run(src).0) == (0+1+2+4+5+6+7) * 100 + 5)
    }
    @Test func listsDictsTuples() throws {
        let src = """
        state = {"phase": "boost", "n": 0}
        items = [1, 2, 3]
        def main():
            state["n"] += 2
            items.append(4)
            a, b = (items[-1], len(items))
            pitch, yaw, roll = craft.attitude()
            if "phase" in state and state.get("missing") is None:
                return a * 10 + b + state["n"] * 100
            return 0
        import craft
        """
        #expect(int(try run(src).0) == 4 * 10 + 4 + 200)
    }
    @Test func mathModule() throws {
        let src = """
        import math
        def main():
            return math.clamp(math.degrees(math.pi), 0.0, 100.0) + math.hypot(3, 4)
        """
        #expect(dbl(try run(src).0) == 105)
    }
    @Test func recursionAndCalls() throws {
        let src = """
        def fib(n):
            if n < 2:
                return n
            return fib(n - 1) + fib(n - 2)
        def main():
            return fib(15)
        """
        #expect(int(try run(src).0) == 610)
    }
    @Test func recursionLimit() throws {
        let src = "def f(n):\n    return f(n + 1)\ndef main():\n    return f(0)\n"
        #expect(throws: VMFault.self) { try run(src) }
        do { _ = try run(src) } catch let f as VMFault { #expect(f.kind == .recursion) }
    }
    @Test func budgetExceeded() throws {
        let src = "def main():\n    while True:\n        pass\n"
        do { _ = try run(src); Issue.record("no fault") } catch let f as VMFault { #expect(f.kind == .budget); #expect(f.line == 2) }
    }
    @Test func divisionByZeroHasLine() throws {
        let src = "def main():\n    x = 1\n    return x / 0\n"
        do { _ = try run(src); Issue.record("no fault") } catch let f as VMFault { #expect(f.kind == .div0); #expect(f.line == 3) }
    }
    @Test func indexFault() throws {
        do { _ = try run("def main():\n    a = [1]\n    return a[3]\n") } catch let f as VMFault {
            #expect(f.message == "Index 3 out of range for length 1")
        }
    }
    @Test func compileErrorsHavePositions() {
        do { _ = try Compiler.compile("def f(:\n    pass\n"); Issue.record("compiled") } catch let e as CompileError {
            #expect(e.line == 1)
        } catch { Issue.record("wrong error") }
        do { _ = try Compiler.compile("x = [i for i in range(3)]\n") } catch let e as CompileError {
            #expect(e.message.contains("Comprehensions"))
        } catch { Issue.record("wrong error") }
        do { _ = try Compiler.compile("if True:\npass\n") } catch let e as CompileError {
            #expect(e.line == 2)
        } catch { Issue.record("wrong error") }
    }
    @Test func craftCallsReachHost() throws {
        let (_, host) = try run("import craft\ndef main():\n    craft.log(craft.altitude())\n")
        #expect(host.log == ["100.0"])
    }
    @Test func chainedCompareAndTernary() throws {
        #expect(int(try run("def main():\n    x = 5\n    return 1 if 0 < x < 10 else 2\n").0) == 1)
    }
    @Test func strFormatting() throws {
        let (v, _) = try run("def main():\n    return str(3) + str(2.5) + str(True) + str(None)\n")
        if case let .str(s) = v { #expect(s == "32.5TrueNone") } else { Issue.record("not str") }
    }
}
