import Foundation
import SpacecraftCore

/// C7 validity rule of specs/15: the first seed in start..<start + tries whose generated course the
/// lesson 6 reference passes; otherwise the C4 field.
public enum CapstoneCourse {
    public static func mission(start: UInt64, reference: String, craft: CraftDesign = .aField(), tries: Int = 20) -> Mission {
        for k in 0..<UInt64(tries) {
            let m = Mission.m7(seed: start &+ k)
            if FlightPreview.run(source: reference, craft: craft, mission: m).result.passed { return m }
        }
        return .m4
    }

    /// Seed from an attempt start time: seconds modulo 2^31.
    public static func seed(for date: Date) -> UInt64 { UInt64(date.timeIntervalSince1970) % (1 << 31) }
}
