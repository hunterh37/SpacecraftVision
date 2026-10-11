import Foundation

/// US Standard Atmosphere 1976, layers to 86 km.
public enum Atmosphere {
    public static let seaLevelPressure = 101_325.0
    static let R = 287.053
    static let layers: [(h: Double, T: Double, lapse: Double, p: Double)] = {
        let base: [(Double, Double)] = [(0, -0.0065), (11_000, 0), (20_000, 0.001), (32_000, 0.0028),
                                        (47_000, 0), (51_000, -0.0028), (71_000, -0.002)]
        var out: [(Double, Double, Double, Double)] = []
        var T = 288.15, p = seaLevelPressure
        for i in 0..<base.count {
            let (h, L) = base[i]
            out.append((h, T, L, p))
            if i + 1 < base.count {
                let dh = base[i + 1].0 - h
                if L == 0 { p *= exp(-g0 * dh / (R * T)) } else {
                    let T2 = T + L * dh
                    p *= pow(T2 / T, -g0 / (L * R)); T = T2
                }
            }
        }
        return out.map { (h: $0.0, T: $0.1, lapse: $0.2, p: $0.3) }
    }()

    public struct Sample: Sendable { public var temperature, pressure, density, speedOfSound: Double }

    public static func at(altitude: Double) -> Sample {
        let h = min(max(altitude, 0), 86_000)
        var l = layers[0]
        for layer in layers where h >= layer.h { l = layer }
        let dh = h - l.h
        let T = l.T + l.lapse * dh
        let p = l.lapse == 0 ? l.p * exp(-g0 * dh / (R * l.T)) : l.p * pow(T / l.T, -g0 / (l.lapse * R))
        let rho = altitude > 86_000 ? 0 : p / (R * T)
        return Sample(temperature: T, pressure: altitude > 86_000 ? 0 : p, density: rho, speedOfSound: sqrt(1.4 * R * T))
    }
}
