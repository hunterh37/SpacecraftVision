import Testing
import Foundation
import SpacecraftCore
import FlightSim
import FlightRunner
import Curriculum
@testable import LabUI

struct PathGeometryTests {
    func report(_ lesson: Int) -> (FlightReport, Course) {
        let l = Lesson.all[lesson]
        let r = FlightPreview.run(source: l.referenceCode, craft: lesson == 2 ? .rGates() : .rHop(), mission: l.mission)
        return (r, l.mission.course)
    }

    @Test func hopIsASideProfileAndEverySampleLandsInsideTheGraph() {
        let (r, c) = report(0)
        let p = PathProjection(samples: r.samples, course: c)
        #expect(p.mode == .side)
        let size = CGSize(width: 600, height: 170)
        for s in r.samples.prefix(400) {
            let pt = p.point(s.position, in: size)
            #expect(pt.x >= -0.5 && pt.x <= size.width + 0.5 && pt.y >= -0.5 && pt.y <= size.height + 0.5)
        }
        // higher is further up the page
        #expect(p.point(Vec3(0, 0, 1000), in: size).y < p.point(Vec3(0, 0, 100), in: size).y)
    }

    @Test func gateCourseIsATopViewWithGatesOrderedLeftToRight() {
        let (r, c) = report(2)
        let p = PathProjection(samples: r.samples, course: c)
        #expect(p.mode == .top)
        let size = CGSize(width: 600, height: 170)
        let xs = c.gates.map { p.point($0.centre, in: size).x }
        #expect(xs == xs.sorted(), "gates are numbered south to north, so left to right")
        // one scale for both axes: a 10 m step east equals a 10 m step north on screen
        let a = p.point(Vec3(0, 0, 0), in: size), e = p.point(Vec3(10, 0, 0), in: size), n = p.point(Vec3(0, 10, 0), in: size)
        #expect(abs(abs(e.y - a.y) - abs(n.x - a.x)) < 1e-6)
    }

    @Test func nearestSampleFindsTheClosestPointOnTheDrawnPath() {
        let (r, c) = report(0)
        let p = PathProjection(samples: r.samples, course: c), size = CGSize(width: 600, height: 170)
        let target = r.samples[r.samples.count / 2]
        let i = p.nearest(r.samples, to: p.point(target.position, in: size), in: size)
        #expect(i != nil && abs(r.samples[i!].position.z - target.position.z) < 5)
    }

    @Test func eventsParseTheirTimes() {
        let ev = PathEvent.parse(["0.0 s  Liftoff", "5.2 s  Engine cutoff", "garbage"])
        #expect(ev.count == 2 && ev[1].time == 5.2 && ev[1].text == "Engine cutoff")
    }

    @Test func sampleLookupByTime() {
        let (r, _) = report(0)
        let i = try! #require(r.samples.index(atTime: 3.0))
        #expect(abs(r.samples[i].t - 3.0) < 0.03)
        #expect(r.samples.index(atTime: -5) == 0 && r.samples.index(atTime: 1e6) == r.samples.count - 1)
    }
}
