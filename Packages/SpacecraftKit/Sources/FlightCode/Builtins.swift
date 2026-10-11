import Foundation

enum Builtins {
    static let names: Set<String> = ["abs", "min", "max", "len", "range", "int", "float", "round", "str", "bool", "print",
                                     "sum", "list"]
    static let math: Set<String> = ["sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sqrt", "hypot", "floor", "ceil",
                                    "exp", "log", "radians", "degrees", "clamp", "fabs", "copysign", "isnan", "isinf"]

    static func num(_ v: Value, _ vm: VM) throws(VMFault) -> Double {
        guard let d = v.asDouble else { throw vm.fault(.type, "Expected float, got \(v.typeName)") }
        return d
    }

    static func argc(_ args: [Value], _ n: ClosedRange<Int>, _ name: String, _ vm: VM) throws(VMFault) {
        guard n.contains(args.count) else { throw vm.fault(.type, "\(name)() takes \(n.lowerBound == n.upperBound ? "\(n.lowerBound)" : "\(n.lowerBound) to \(n.upperBound)") arguments, got \(args.count)") }
    }

    static func sequence(_ v: Value, _ vm: VM) throws(VMFault) -> [Value] {
        switch v {
        case let .list(l): return l.items
        case let .tuple(t): return t
        case let .dict(d): return d.order.map { d.map[$0]!.key }
        default: throw vm.fault(.type, "'\(v.typeName)' is not iterable")
        }
    }

    static func call(_ name: String, _ args: [Value], _ vm: VM) throws(VMFault) -> Value {
        switch name {
        case "abs":
            try argc(args, 1...1, name, vm)
            if case let .int(i) = args[0] { return .int(abs(i)) }
            return .float(abs(try num(args[0], vm)))
        case "min", "max":
            guard !args.isEmpty else { throw vm.fault(.type, "\(name)() expects at least 1 argument") }
            let items = args.count == 1 ? try sequence(args[0], vm) : args
            guard var best = items.first else { throw vm.fault(.value, "\(name)() arg is an empty sequence") }
            for x in items.dropFirst() {
                let less = try vm.compare(.lt, x, best)
                let more = try vm.compare(.gt, x, best)
                if (name == "min" && less) || (name == "max" && more) { best = x }
            }
            return best
        case "sum":
            try argc(args, 1...1, name, vm)
            var acc: Value = .int(0)
            for x in try sequence(args[0], vm) { acc = try vm.binary(.add, acc, x) }
            return acc
        case "len":
            try argc(args, 1...1, name, vm)
            switch args[0] {
            case let .str(s): return .int(s.count)
            case let .list(l): return .int(l.items.count)
            case let .tuple(t): return .int(t.count)
            case let .dict(d): return .int(d.order.count)
            default: throw vm.fault(.type, "Object of type \(args[0].typeName) has no len()")
            }
        case "range":
            try argc(args, 1...3, name, vm)
            var ints: [Int] = []
            for a in args {
                guard case let .int(i) = a.intLike ?? .none else { throw vm.fault(.type, "Expected int, got \(a.typeName)") }
                ints.append(i)
            }
            let (start, stop, step) = ints.count == 1 ? (0, ints[0], 1) : (ints[0], ints[1], ints.count == 3 ? ints[2] : 1)
            guard step != 0 else { throw vm.fault(.value, "range() step must not be zero") }
            let n = max(0, step > 0 ? (stop - start + step - 1) / step : (start - stop - step - 1) / -step)
            try vm.alloc(n)
            return .list(ListRef((0..<n).map { .int(start + $0 * step) }))
        case "list":
            try argc(args, 0...1, name, vm)
            if args.isEmpty { return .list(ListRef([])) }
            let items = try sequence(args[0], vm); try vm.alloc(items.count)
            return .list(ListRef(items))
        case "int":
            try argc(args, 1...1, name, vm)
            switch args[0] {
            case let .int(i): return .int(i)
            case let .bool(b): return .int(b ? 1 : 0)
            case let .float(d):
                guard d.isFinite, abs(d) < 9e18 else { throw vm.fault(.value, "Cannot convert \(d) to int") }
                return .int(Int(d))
            case let .str(s):
                guard let i = Int(s.trimmingCharacters(in: .whitespaces)) else { throw vm.fault(.value, "Invalid literal for int(): '\(s)'") }
                return .int(i)
            default: throw vm.fault(.type, "Expected number, got \(args[0].typeName)")
            }
        case "float":
            try argc(args, 1...1, name, vm)
            if case let .str(s) = args[0] {
                guard let d = Double(s.trimmingCharacters(in: .whitespaces)) else { throw vm.fault(.value, "Could not convert string to float: '\(s)'") }
                return .float(d)
            }
            return .float(try num(args[0], vm))
        case "round":
            try argc(args, 1...2, name, vm)
            let x = try num(args[0], vm)
            if args.count == 2 {
                let n = try num(args[1], vm)
                let f = pow(10, n)
                return .float((x * f).rounded(.toNearestOrEven) / f)
            }
            guard x.isFinite else { throw vm.fault(.value, "Cannot round \(x)") }
            return .int(Int(x.rounded(.toNearestOrEven)))
        case "str":
            try argc(args, 1...1, name, vm)
            return .str(args[0].repr)
        case "bool":
            try argc(args, 1...1, name, vm)
            return .bool(args[0].truthy)
        case "print":
            return try vm.callBuiltin("craft.log", [.str(args.map(\.repr).joined(separator: " "))])
        default:
            throw vm.fault(.name, "Name '\(name)' is not defined")
        }
    }

    static func math(_ name: String, _ args: [Value], _ vm: VM) throws(VMFault) -> Value {
        func a(_ i: Int) throws(VMFault) -> Double { try num(args[i], vm) }
        switch name {
        case "atan2": try argc(args, 2...2, "math.atan2", vm); return .float(atan2(try a(0), try a(1)))
        case "hypot":
            try argc(args, 2...3, "math.hypot", vm)
            var s = 0.0
            for i in 0..<args.count { let v = try a(i); s += v * v }
            return .float(s.squareRoot())
        case "clamp":
            try argc(args, 3...3, "math.clamp", vm)
            return .float(min(max(try a(0), try a(1)), try a(2)))
        case "copysign": try argc(args, 2...2, "math.copysign", vm); return .float(copysign(try a(0), try a(1)))
        case "log":
            try argc(args, 1...2, "math.log", vm)
            let x = try a(0)
            guard x > 0 else { throw vm.fault(.value, "math domain error") }
            return .float(args.count == 2 ? Foundation.log(x) / Foundation.log(try a(1)) : Foundation.log(x))
        default: break
        }
        try argc(args, 1...1, "math.\(name)", vm)
        let x = try a(0)
        switch name {
        case "sin": return .float(sin(x))
        case "cos": return .float(cos(x))
        case "tan": return .float(tan(x))
        case "asin", "acos":
            guard abs(x) <= 1 else { throw vm.fault(.value, "math domain error") }
            return .float(name == "asin" ? asin(x) : acos(x))
        case "atan": return .float(atan(x))
        case "sqrt":
            guard x >= 0 else { throw vm.fault(.value, "math domain error") }
            return .float(x.squareRoot())
        case "floor": return .int(Int(x.rounded(.down)))
        case "ceil": return .int(Int(x.rounded(.up)))
        case "exp": return .float(exp(x))
        case "radians": return .float(x * .pi / 180)
        case "degrees": return .float(x * 180 / .pi)
        case "fabs": return .float(abs(x))
        case "isnan": return .bool(x.isNaN)
        case "isinf": return .bool(x.isInfinite)
        default: throw vm.fault(.name, "math has no attribute '\(name)'")
        }
    }
}
