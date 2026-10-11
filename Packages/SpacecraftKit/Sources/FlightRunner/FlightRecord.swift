import Foundation
import SpacecraftCore
import FlightSim
import FlightCode

/// One recorded flight (specs/11 FlightRecord): enough to replay, compare and export it.
/// Course id and seed are kept so generated C7 courses rebuild exactly.
public struct FlightRecord: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var date: Date
    public var missionId: String
    public var courseId: String
    public var seed: UInt64
    public var craft: CraftDesign
    public var source: String
    public var language: String
    public var result: FlightResult
    public var samples: [FlightSample]
    public var series: [String: [Double]]
    public var seriesTime: [String: [Double]]
    public var events: [String]

    public init(id: UUID = UUID(), name: String, date: Date = Date(), missionId: String, courseId: String, seed: UInt64 = 1,
                craft: CraftDesign, source: String, language: String = "python", report: FlightReport) {
        self.id = id; self.name = name; self.date = date; self.missionId = missionId; self.courseId = courseId; self.seed = seed
        self.craft = craft; self.source = source; self.language = language; result = report.result; samples = report.samples
        series = report.series; seriesTime = report.seriesTime; events = report.events
    }

    public var report: FlightReport {
        FlightReport(result: result, samples: samples, series: series, seriesTime: seriesTime, events: events, faults: [],
                     compileError: nil)
    }

    public var mission: Mission? { Mission.named(missionId) }
    public var course: Course? { Course.named(courseId) }

    /// Telemetry in the 3 s before the failure (specs/08 failure report).
    public var failureWindow: [FlightSample] {
        guard let f = result.failure else { return [] }
        return samples.filter { $0.t >= f.time - 3 && $0.t <= f.time }
    }

    /// Lines changed between two sources (run compare diff summary).
    public static func linesChanged(_ a: String, _ b: String) -> Int {
        let x = a.components(separatedBy: "\n"), y = b.components(separatedBy: "\n")
        // LCS length on lines.
        var prev = [Int](repeating: 0, count: y.count + 1)
        for i in 0..<x.count {
            var cur = [Int](repeating: 0, count: y.count + 1)
            for j in 0..<y.count { cur[j + 1] = x[i] == y[j] ? prev[j] + 1 : max(prev[j + 1], cur[j]) }
            prev = cur
        }
        let common = prev[y.count]
        return max(x.count, y.count) - common
    }
}

/// Saved app state (specs/11): crafts, code, lesson progress and flight records, one JSON file.
public struct SaveState: Codable, Sendable, Equatable {
    public struct Progress: Codable, Sendable, Equatable {
        public var lessonId: Int
        public var stars: Int
        public var bestScore: Int
        public var attempts: Int
        public var hintsUsed: Int
        public init(lessonId: Int, stars: Int, bestScore: Int = 0, attempts: Int = 0, hintsUsed: Int = 0) {
            self.lessonId = lessonId; self.stars = stars; self.bestScore = bestScore; self.attempts = attempts; self.hintsUsed = hintsUsed
        }
    }
    public var version = 1
    public var crafts: [CraftDesign] = []
    public var currentCraftId: UUID?
    public var missionId: String?
    public var sources: [String: String] = [:]
    public var progress: [Progress] = []
    public var answers: [Int: Int] = [:]
    public var records: [FlightRecord] = []
    public init() {}

    public static func == (a: SaveState, b: SaveState) -> Bool {
        a.crafts == b.crafts && a.currentCraftId == b.currentCraftId && a.missionId == b.missionId && a.sources == b.sources
            && a.progress == b.progress && a.answers == b.answers && a.records.map(\.id) == b.records.map(\.id)
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> SaveState {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(SaveState.self, from: data)
    }

    /// Default file: Application Support/VisionSpacecraft/save.json.
    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("VisionSpacecraft", isDirectory: true).appendingPathComponent("save.json")
    }

    public func write(to url: URL = SaveState.defaultURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoded().write(to: url, options: .atomic)
    }

    public static func read(from url: URL = SaveState.defaultURL) -> SaveState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decode(data)
    }
}

/// Interpolated playback of recorded samples.
public struct ReplayCursor: Sendable {
    public let samples: [FlightSample]
    public init(samples: [FlightSample]) { self.samples = samples }
    public var duration: Double { samples.last?.t ?? 0 }

    /// Sample at time t, linearly interpolated (angles on the short way round).
    public func sample(at t: Double) -> FlightSample? {
        guard let first = samples.first else { return nil }
        if t <= first.t { return first }
        guard let last = samples.last, t < last.t else { return samples.last }
        var lo = 0, hi = samples.count - 1
        while hi - lo > 1 { let m = (lo + hi) / 2; if samples[m].t <= t { lo = m } else { hi = m } }
        let a = samples[lo], b = samples[hi]
        let f = b.t > a.t ? (t - a.t) / (b.t - a.t) : 0
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * f }
        func ang(_ x: Double, _ y: Double) -> Double { x + wrapAngle(y - x) * f }
        var s = a
        s.t = t
        s.position = a.position + (b.position - a.position) * f
        s.velocity = a.velocity + (b.velocity - a.velocity) * f
        s.pitch = mix(a.pitch, b.pitch); s.yaw = ang(a.yaw, b.yaw); s.roll = ang(a.roll, b.roll)
        s.throttle = mix(a.throttle, b.throttle); s.fuel = mix(a.fuel, b.fuel); s.energy = mix(a.energy, b.energy)
        s.maxTemp = mix(a.maxTemp, b.maxTemp)
        return s
    }
}
