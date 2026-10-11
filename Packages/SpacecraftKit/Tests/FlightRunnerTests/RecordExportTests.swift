import Testing
import Foundation
import SpacecraftCore
import FlightSim
@testable import FlightRunner
import Curriculum

struct RecordExportTests {
    func record() -> FlightRecord {
        let l = Lesson.all[0]
        let rep = FlightPreview.run(source: l.referenceCode, craft: .rHop(), mission: l.mission)
        return FlightRecord(name: "hop 1", missionId: l.missionId, courseId: l.mission.courseId, craft: .rHop(), source: l.referenceCode, report: rep)
    }

    @Test func csvHasHeaderAndOneRowPerSample() {
        let r = record()
        let lines = FlightExport.csv(r).split(separator: "\n")
        #expect(lines.count == r.samples.count + 1)
        #expect(lines[0].hasPrefix("t,x,y,z"))
        #expect(lines[1].split(separator: ",").count == lines[0].split(separator: ",").count)
    }

    @Test func mScriptReadsTheCsv() {
        let m = FlightExport.mScript(record(), csvName: "hop.csv")
        #expect(m.contains("readtable('hop.csv')"))
        #expect(m.contains("xlabel('t (s)')"))
        #expect(FlightExport.sanitize("1 bad-name") == "s_1_bad_name")
    }

    @Test func saveStateRoundTrips() throws {
        var s = SaveState()
        s.crafts = [.rHop()]; s.missionId = "M1"; s.sources = ["M1": "x"]
        s.progress = [.init(lessonId: 0, stars: 2, bestScore: 85)]; s.records = [record()]
        let back = try SaveState.decode(try s.encoded())
        #expect(back == s)
        #expect(back.records[0].samples.count == s.records[0].samples.count)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("save.json")
        try s.write(to: url)
        #expect(SaveState.read(from: url) == s)
    }

    @Test func replayInterpolatesAndClamps() {
        let r = record()
        let c = ReplayCursor(samples: r.samples)
        let mid = c.sample(at: c.duration / 2)!
        #expect(abs(mid.t - c.duration / 2) < 1e-9)
        #expect(c.sample(at: -5)!.t == r.samples[0].t)
        #expect(c.sample(at: c.duration + 10)!.t == r.samples.last!.t)
    }

    @Test func diffCountsChangedLines() {
        #expect(FlightRecord.linesChanged("a\nb\nc", "a\nB\nc") == 1)
        #expect(FlightRecord.linesChanged("a", "a") == 0)
    }

    @Test func c7RecordRebuildsItsCourse() {
        let c = Course.named("C7-4")
        #expect(c?.id == "C7-4")
    }
}
