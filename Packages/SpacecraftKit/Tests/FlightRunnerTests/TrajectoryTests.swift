import Testing
import Foundation
import SpacecraftCore
import FlightSim
@testable import FlightRunner
import Curriculum

struct TrajectoryTests {
    let l0 = Lesson.all[0]

    func report(_ src: String) -> FlightReport { FlightPreview.run(source: src, craft: .rHop(), mission: l0.mission) }

    @Test func layoutDecimatesAndKeepsTheShape() {
        let r = report(l0.referenceCode)
        let t = TrajectoryLayout.make(samples: r.samples, events: TrajectoryLayout.parseEvents(r.events), result: r.result)
        #expect(t.points.count <= 262 && t.points.count > 50)
        #expect(t.points.first?.position.z == r.samples.first?.position.z)
        #expect(abs(t.points[t.apexIndex].position.z - r.result.apogee) < 1.0)
        #expect(t.points.map(\.t) == t.points.map(\.t).sorted())
        #expect(t.extent >= r.result.apogee * 0.9)
    }

    @Test func pinsIncludeApogeeEventsAndOutcome() {
        let r = report(l0.referenceCode)
        let t = TrajectoryLayout.make(samples: r.samples, events: TrajectoryLayout.parseEvents(r.events), result: r.result)
        #expect(t.pins.contains { $0.kind == .apogee })
        #expect(t.pins.contains { $0.kind == .landing })
        #expect(t.pins.filter { $0.kind == .event }.count >= 1)
        let bad = report(l0.starterCode)
        let tb = TrajectoryLayout.make(samples: bad.samples, events: TrajectoryLayout.parseEvents(bad.events), result: bad.result)
        #expect(tb.pins.contains { $0.kind == .failure })
        #expect(!tb.pins.contains { $0.kind == .landing })
    }

    @Test func interpolationClampsAndIsContinuous() {
        let r = report(l0.referenceCode)
        let t = TrajectoryLayout.make(samples: r.samples, events: [], result: r.result)
        #expect(t.position(at: -5) == t.points.first?.position)
        #expect(t.position(at: 1e6) == t.points.last?.position)
        let mid = t.position(at: t.duration / 2)
        #expect(mid.z > 0)
        #expect(t.index(at: t.duration) == t.points.count - 1)
        #expect(t.index(at: 0) == 0)
    }

    @Test func parseEventsIgnoresNoise() {
        let e = TrajectoryLayout.parseEvents(["12.3 s  Engine cutoff", "garbage", "0.0 s  Liftoff"])
        #expect(e.count == 2 && e[0].t == 12.3 && e[0].text == "Engine cutoff")
    }

    @Test func verdictWorkedFailedAndPending() {
        let good = report(l0.referenceCode), bad = report(l0.starterCode)
        let vg = FlightVerdict.make(live: false, result: good.result, faults: good.faults, forecast: good)
        #expect(vg.state == .worked && vg.headline == "CODE WORKED" && vg.forecastNote == "Matches the forecast.")
        let vb = FlightVerdict.make(live: false, result: bad.result, faults: bad.faults, forecast: bad)
        #expect(vb.state == .failed && vb.detail.contains(bad.result.failure!.title))
        #expect(FlightVerdict.make(live: true, result: nil, faults: [], forecast: nil).state == .flying)
        let pending = FlightVerdict.make(live: false, result: nil, faults: [], forecast: good)
        #expect(pending.state == .noFlight && pending.detail.contains("pass"))
    }

    @Test func verdictCarriesTheFaultingLine() {
        let src = "import craft\ndef update(dt):\n    x = 1\n    y = x / 0\n"
        let r = FlightPreview.run(source: src, craft: .rHop(), mission: l0.mission)
        let v = FlightVerdict.make(live: false, result: r.result, faults: r.faults, forecast: r)
        #expect(v.state == .failed)
        #expect(v.line == 4, "\(v.line.map(String.init) ?? "nil") \(r.faults)")
    }

    @Test func forecastMismatchIsCalledOut() {
        let good = report(l0.referenceCode), bad = report(l0.starterCode)
        let v = FlightVerdict.make(live: false, result: bad.result, faults: [], forecast: good)
        #expect(v.forecastNote?.contains("Differs") == true)
    }
}
