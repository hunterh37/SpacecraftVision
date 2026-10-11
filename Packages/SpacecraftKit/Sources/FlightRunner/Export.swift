import Foundation
import SpacecraftCore
import FlightSim

/// CSV and MATLAB/Octave export of a flight (specs/08 Export).
public enum FlightExport {
    public static let columns = ["t", "x", "y", "z", "vx", "vy", "vz", "speed", "pitch_deg", "yaw_deg", "roll_deg",
                                 "throttle", "fuel", "energy_wh", "max_temp_k", "clearance_m"]

    /// All channels at 50 Hz, plus user series sampled at the nearest earlier value.
    public static func csv(_ r: FlightRecord) -> String {
        let user = r.series.keys.sorted()
        var lines = [(columns + user.map(sanitize)).joined(separator: ",")]
        var idx = [String: Int]()
        for s in r.samples {
            var row: [String] = [s.t, s.position.x, s.position.y, s.position.z, s.velocity.x, s.velocity.y, s.velocity.z, s.speed,
                                 s.pitch * 180 / .pi, s.yaw * 180 / .pi, s.roll * 180 / .pi, s.throttle, s.fuel, s.energy,
                                 s.maxTemp].map { num($0) }
            row.append(s.clearance.map { num($0) } ?? "NaN")
            for k in user {
                let ts = r.seriesTime[k] ?? [], vs = r.series[k] ?? []
                var i = idx[k] ?? -1
                while i + 1 < min(ts.count, vs.count) && ts[i + 1] <= s.t + 1e-9 { i += 1 }
                idx[k] = i
                row.append(i >= 0 ? num(vs[i]) : "NaN")
            }
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Script that loads the CSV and recreates the default figures in MATLAB or Octave.
    public static func mScript(_ r: FlightRecord, csvName: String) -> String {
        let user = r.series.keys.sorted().map(sanitize)
        var s = """
        % \(r.name): mission \(r.missionId), course \(r.courseId), seed \(r.seed)
        % Result: \(r.result.passed ? "pass" : "fail\(r.result.failure.map { " - " + $0.title } ?? "")"), score \(r.result.score)
        d = readtable('\(csvName)');
        set(groot, 'defaultAxesColorOrder', [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250; 0.4940 0.1840 0.5560; 0.4660 0.6740 0.1880]);
        figure('Name', 'Altitude'); plot(d.t, d.z); grid on; xlabel('t (s)'); ylabel('altitude (m)');
        figure('Name', 'Speed'); plot(d.t, d.speed); grid on; xlabel('t (s)'); ylabel('speed (m/s)');
        figure('Name', 'Throttle'); plot(d.t, d.throttle); grid on; xlabel('t (s)'); ylabel('throttle');
        figure('Name', 'Fuel and energy'); yyaxis left; plot(d.t, d.fuel); ylabel('fuel (0..1)'); yyaxis right; plot(d.t, d.energy_wh); ylabel('energy (Wh)'); grid on; xlabel('t (s)');
        figure('Name', 'Max part temperature'); plot(d.t, d.max_temp_k); grid on; xlabel('t (s)'); ylabel('temperature (K)');
        figure('Name', 'Closest obstacle'); plot(d.t, d.clearance_m); grid on; xlabel('t (s)'); ylabel('clearance (m)');
        figure('Name', 'Top-down path'); plot(d.x, d.y); axis equal; grid on; xlabel('x east (m)'); ylabel('y north (m)');
        figure('Name', 'Side profile'); plot(hypot(d.x, d.y), d.z); grid on; xlabel('downrange (m)'); ylabel('altitude (m)');

        """
        for u in user { s += "figure('Name', '\(u)'); plot(d.t, d.\(u)); grid on; xlabel('t (s)'); ylabel('\(u)');\n" }
        return s
    }

    /// Valid MATLAB identifier for a user series name.
    public static func sanitize(_ name: String) -> String {
        var out = String(name.map { $0.isLetter || $0.isNumber || $0 == "_" ? $0 : "_" })
        if out.first.map({ !$0.isLetter }) ?? true { out = "s_" + out }
        return out
    }

    static func num(_ v: Double) -> String { v.isFinite ? String(format: "%.6g", v) : "NaN" }

    /// Writes CSV, .m and source into a temporary folder; returns the file URLs.
    public static func write(_ r: FlightRecord, to dir: URL = FileManager.default.temporaryDirectory) throws -> [URL] {
        let base = sanitize(r.name.isEmpty ? "flight" : r.name)
        let folder = dir.appendingPathComponent("\(base)-export", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let csvURL = folder.appendingPathComponent("\(base).csv")
        let mURL = folder.appendingPathComponent("\(base)_plots.m")
        let srcURL = folder.appendingPathComponent("\(base).\(r.language == "c" ? "c" : "py")")
        try csv(r).write(to: csvURL, atomically: true, encoding: .utf8)
        try mScript(r, csvName: csvURL.lastPathComponent).write(to: mURL, atomically: true, encoding: .utf8)
        try r.source.write(to: srcURL, atomically: true, encoding: .utf8)
        return [csvURL, mURL, srcURL]
    }
}
