#if DEBUG
import SwiftUI
import DicyaninStageDirector
import SpacecraftCore
import Curriculum

/// DicyaninStageDirector routes: one per scene so /vision-screenshot and /vision-record-demo reach every view
/// without touching the Simulator. Paths: home/*, workshop/*, range/<course>/<view>[/fly], lesson/<n>/<stage>, analysis.
@MainActor
enum DemoRoutes {
    static func register(_ b: RouteBook, model: AppModel) {
        nonisolated(unsafe) let m = model
        func openRange(_ take: Take) async {
            await take.openImmersive(SpaceID.range.rawValue)
            m.openSpace = .range
        }
        b.group("home") { b in
            for mode in GameMode.allCases {
                b.route(mode.rawValue, "Home, \(mode.rawValue) tab", duration: 6) { take in
                    m.showMode(mode)
                    await take.wait(1.5); await take.ready(); await take.wait(4); take.done()
                }
            }
            b.route("settings", "Settings screen", duration: 6) { take in
                m.homePath = NavigationPath(); m.homePath.append(SettingsRoute.main)
                await take.wait(1.5); await take.ready(); await take.wait(4); take.done()
            }
        }
        b.group("workshop") { b in
            b.route("hangar", "Hangar with the current craft", duration: 10) { take in
                await take.openImmersive(SpaceID.workshop.rawValue); m.openSpace = .workshop
                await take.wait(6); await take.ready(); await take.wait(6); take.done()
            }
            b.route("parts", "Part picker window", duration: 6) { take in
                take.openWindow(WindowID.parts)
                await take.wait(2); await take.ready(); await take.wait(4); take.done()
            }
        }
        b.group("range") { b in
            for mission in Mission.all + [Mission.m7(seed: 2), Mission.m7(seed: 3)] {
                let craft = referenceCraft(for: mission)
                for view in FlightView.allCases {
                    let base = "\(mission.course.id.lowercased())/\(view.rawValue)"
                    b.route(base, "\(mission.title) course, \(view.label) view", duration: 10) { take in
                        m.mission = mission; m.craft = craft; m.flightView = view
                        await openRange(take)
                        await take.wait(6); await take.ready(); await take.wait(6); take.done()
                    }
                    b.route(base + "/fly", "\(mission.title) flown with the lesson reference, \(view.label) view", duration: 40) { take in
                        m.mission = mission; m.craft = craft; m.flightView = view
                        if let ref = m.lessonReference(for: mission) { m.source = ref }
                        await openRange(take)
                        await take.wait(6); await take.ready()
                        m.flight.timeScale = take.param("speed", default: 4)
                        take.cue("launch"); m.launch()
                        await take.wait(take.param("seconds", default: 30)); take.done()
                    }
                }
            }
        }
        b.group("lesson") { b in
            for l in Lesson.all {
                for stage in LessonStage.allCases {
                    b.route("\(l.id)/\(String(describing: stage))", "Lesson \(l.id) \(stage.title)", duration: 6) { take in
                        m.select(lesson: l); m.showMode(.learn); m.homePath.append(l); m.lessonStage = stage
                        await take.wait(1.5); await take.ready(); await take.wait(4); take.done()
                    }
                }
            }
        }
        b.route("analysis", "Analysis window for the selected lesson's preview", duration: 8) { take in
            for _ in 0..<40 { if m.preview != nil { break }; await take.wait(0.25) }
            m.lastReport = m.preview; m.reports = m.preview.map { [$0] } ?? []
            take.openWindow(WindowID.analysis)
            await take.wait(2); await take.ready(); await take.wait(5); take.done()
        }
        b.route("code", "Code editor window", duration: 6) { take in
            take.openWindow(WindowID.code)
            await take.wait(2); await take.ready(); await take.wait(4); take.done()
        }
    }

    /// Reference craft per course (specs/15).
    static func referenceCraft(for m: Mission) -> CraftDesign {
        switch m.courseId {
        case "C1", "C1W": .rHop()
        case "C2", "C3": .rGates()
        case "C2B": .rWalls()
        case "C6": .rDebris()
        default: m.isAircraft ? .aField() : .rHop()
        }
    }
}
#endif
