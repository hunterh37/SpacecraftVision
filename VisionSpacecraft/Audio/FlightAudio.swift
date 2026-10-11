import Foundation
import RealityKit

/// Flight sound (specs/09): engine roar and crackle or propeller buzz on the craft as spatial sources, wind by
/// dynamic pressure in chase view, and short UI cues. Loops are synthesized once into WAV files in Caches
/// (no licensed library is bundled yet). Gain and pitch follow throttle and dynamic pressure.
@MainActor
final class FlightAudio {
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundEffects") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundEffects") }
    }

    let engineSource = Entity()
    let windSource = Entity()
    let cueSource = Entity()
    private var roar: AudioPlaybackController?
    private var crackle: AudioPlaybackController?
    private var prop: AudioPlaybackController?
    private var wind: AudioPlaybackController?
    private var cues: [String: AudioFileResource] = [:]
    private var loaded = false

    init() {
        engineSource.components.set(SpatialAudioComponent(gain: 0))
        windSource.components.set(AmbientAudioComponent(gain: 0))
        cueSource.components.set(AmbientAudioComponent(gain: -6))
    }

    /// Attach the engine source to the craft and the wind/cue sources near the listener.
    func attach(craft: Entity, listener: Entity) {
        if engineSource.parent !== craft { craft.addChild(engineSource) }
        if windSource.parent !== listener { listener.addChild(windSource) }
        if cueSource.parent !== listener { listener.addChild(cueSource) }
        guard !loaded else { return }
        loaded = true
        func loop(_ name: String, _ gen: () -> [Float]) -> AudioFileResource? {
            guard let url = Self.wav(name, gen) else { return nil }
            return try? AudioFileResource.load(contentsOf: url, configuration: .init(shouldLoop: true))
        }
        if let r = loop("roar", { Self.brownNoise(seconds: 3, seed: 1) }) { roar = engineSource.prepareAudio(r) }
        if let r = loop("crackle", { Self.crackle(seconds: 3) }) { crackle = engineSource.prepareAudio(r) }
        if let r = loop("prop", { Self.buzz(seconds: 2, hz: 88) }) { prop = engineSource.prepareAudio(r) }
        if let r = loop("wind", { Self.brownNoise(seconds: 4, seed: 7, smooth: 0.995) }) { wind = windSource.prepareAudio(r) }
        for (name, f, d) in [("launch", 440.0, 0.25), ("pass", 880.0, 0.35), ("fail", 180.0, 0.6), ("ok", 660.0, 0.12), ("error", 220.0, 0.2)] {
            if let url = Self.wav("cue-\(name)", { Self.tone(hz: f, seconds: d, glide: name == "pass" ? 1.5 : name == "fail" ? 0.6 : 1) }),
               let res = try? AudioFileResource.load(contentsOf: url) { cues[name] = res }
        }
        for c in [roar, crackle, prop, wind] { c?.gain = -80; c?.play() }
    }

    func update(throttle: Double, dynamicPressure q: Double, propeller: Bool, chase: Bool, flying: Bool) {
        guard loaded else { return }
        let on = Self.enabled && flying
        let t = on ? throttle : 0
        if propeller {
            prop?.gain = t > 0.01 ? -20 + 18 * t : -80
            prop?.speed = 0.7 + 0.6 * t
            roar?.gain = -80; crackle?.gain = -80
        } else {
            roar?.gain = t > 0.01 ? -14 + 14 * t : -80
            roar?.speed = 0.8 + 0.4 * t
            crackle?.gain = t > 0.01 ? -24 + 14 * t : -80
            prop?.gain = -80
        }
        // Wind noise by dynamic pressure, chase view only: -40 dB at 0.1 kPa up to -4 dB at 20 kPa.
        if on && chase && q > 100 {
            wind?.gain = min(-4, -40 + 12 * log10(q / 100) * 2.3)
            wind?.speed = 0.8 + min(0.6, q / 40_000)
        } else {
            wind?.gain = -80
        }
    }

    func cue(_ name: String) {
        guard Self.enabled, let r = cues[name] else { return }
        cueSource.playAudio(r)
    }

    // MARK: Synthesis

    static let rate = 44_100.0

    static func wav(_ name: String, _ gen: () -> [Float]) -> URL? {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("audio-v1")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let samples = gen()
        var data = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 2)) }
        let bytes = UInt32(samples.count * 2)
        data.append("RIFF".data(using: .ascii)!); u32(36 + bytes); data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        data.append("data".data(using: .ascii)!); u32(bytes)
        for s in samples { u16(UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32_000))) }
        do { try data.write(to: url); return url } catch { return nil }
    }

    struct RNG { var s: UInt64; mutating func next() -> Float { s = s &* 6364136223846793005 &+ 1442695040888963407; return Float(s >> 40) / Float(1 << 24) * 2 - 1 } }

    /// Low-passed noise; loop seam hidden by a crossfade.
    static func brownNoise(seconds: Double, seed: UInt64, smooth: Float = 0.97) -> [Float] {
        var r = RNG(s: seed), y: Float = 0
        let n = Int(seconds * rate)
        var out = (0..<n).map { _ -> Float in y = smooth * y + (1 - smooth) * r.next() * 6; return y }
        let peak = out.map(abs).max() ?? 1
        out = out.map { $0 / max(peak, 1e-3) * 0.8 }
        return crossfade(out)
    }

    static func crackle(seconds: Double) -> [Float] {
        var r = RNG(s: 3)
        let n = Int(seconds * rate)
        var out = [Float](repeating: 0, count: n)
        var i = 0
        while i < n - 400 {
            let amp = 0.3 + 0.6 * abs(r.next())
            for k in 0..<300 { out[i + k] += amp * r.next() * exp(-Float(k) / 40) }
            i += 200 + Int(abs(r.next()) * 1800)
        }
        return crossfade(out)
    }

    static func buzz(seconds: Double, hz: Double) -> [Float] {
        let n = Int(seconds * rate)
        return (0..<n).map { i in
            let t = Double(i) / rate
            let p = (t * hz).truncatingRemainder(dividingBy: 1)
            return Float((2 * p - 1) * 0.35 + sin(2 * .pi * hz * 3 * t) * 0.15)
        }
    }

    static func tone(hz: Double, seconds: Double, glide: Double) -> [Float] {
        let n = Int(seconds * rate)
        var phase = 0.0
        return (0..<n).map { i in
            let f = Double(i) / Double(n)
            phase += 2 * .pi * hz * (1 + (glide - 1) * f) / rate
            let env = min(1, f * 40) * (1 - f)
            return Float(sin(phase) * env * 0.6)
        }
    }

    static func crossfade(_ s: [Float]) -> [Float] {
        let m = min(4410, s.count / 4)
        guard m > 0 else { return s }
        var out = Array(s[m...])
        for k in 0..<m { let a = Float(k) / Float(m); out[out.count - m + k] = out[out.count - m + k] * (1 - a) + s[k] * a }
        return out
    }
}
