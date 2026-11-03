import Foundation

/// The knock, synthesized when a skin is worn. A few decaying modes, a short
/// mallet burst, and the same strike heard in one wooden hall. Nothing is
/// stored: a skin names a voice, and the voice is a handful of numbers.
enum KnockSynth {
    static let sampleRate: Float = 44100
    static let voices = ["wood", "lacquer", "ink", "cartoon", "pixel", "jade", "bowl", "key", "bamboo", "stone", "piston", "crt"]

    struct Variation {
        var dry: [Float]
        var left: [Float]
        var right: [Float]
    }

    static func resolve(_ name: String?) -> String {
        guard let name, tones[name] != nil else { return "wood" }
        return name
    }

    /// Three strikes of `name`, so a run of knocks is not one recording played again.
    static func prepare(_ name: String) -> [Variation] {
        let tone = tones[resolve(name)]!
        return tone.bases.enumerated().map { i, base in
            let dry = strike(tone, base: base, seed: tone.seed &+ UInt64(i))
            let hall = Hall.render(dry)
            return Variation(dry: dry, left: hall.left, right: hall.right)
        }
    }

    private struct Mode {
        var ratio: Float
        var amp: Float
        var tau: Float
        var cents: Float = 0
    }

    private struct Noise {
        var amp: Float
        var tau: Float
        var low: Float
        var high: Float
    }

    private struct Tone {
        var bases: [Float]
        var length: Float
        var seed: UInt64
        var modes: [Mode]
        var body: Mode?
        var noise: Noise?
        var attack: Float
        var lowpass: Float?
        var crush = false
    }

    // The long ring lives in the hall, so a fast run of knocks — typing — stays a strike.
    private static let tones: [String: Tone] = [
        "wood": Tone(
            bases: [612, 598, 625], length: 0.9, seed: 1,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.110), Mode(ratio: 1.52, amp: 0.45, tau: 0.070),
                    Mode(ratio: 2.31, amp: 0.30, tau: 0.045), Mode(ratio: 3.07, amp: 0.18, tau: 0.030),
                    Mode(ratio: 4.63, amp: 0.10, tau: 0.018)],
            body: Mode(ratio: 0.5, amp: 0.35, tau: 0.16),
            noise: Noise(amp: 0.6, tau: 0.004, low: 1500, high: 7000), attack: 0.001),
        // Hard lacquered shell: the same hollow fish, higher, with a sharper click.
        "lacquer": Tone(
            bases: [820, 802, 840], length: 0.62, seed: 11,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.070), Mode(ratio: 1.47, amp: 0.48, tau: 0.040),
                    Mode(ratio: 2.30, amp: 0.28, tau: 0.024), Mode(ratio: 3.15, amp: 0.14, tau: 0.014),
                    Mode(ratio: 5.60, amp: 0.08, tau: 0.008)],
            body: Mode(ratio: 0.55, amp: 0.14, tau: 0.07),
            noise: Noise(amp: 0.42, tau: 0.0032, low: 3200, high: 10000), attack: 0.0005),
        // A painting of the fish: the wooden modes, heard through paper.
        "ink": Tone(
            bases: [392, 380, 404], length: 1.05, seed: 23,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.18), Mode(ratio: 1.50, amp: 0.32, tau: 0.10),
                    Mode(ratio: 2.28, amp: 0.12, tau: 0.05)],
            body: Mode(ratio: 0.48, amp: 0.55, tau: 0.24),
            noise: Noise(amp: 0.22, tau: 0.010, low: 350, high: 1400), attack: 0.008, lowpass: 1500),
        // A small light fish. Round, short, almost no grit.
        "cartoon": Tone(
            bases: [520, 508, 534], length: 0.48, seed: 37,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.065), Mode(ratio: 1.50, amp: 0.30, tau: 0.038),
                    Mode(ratio: 2.40, amp: 0.07, tau: 0.018)],
            body: Mode(ratio: 0.50, amp: 0.16, tau: 0.07),
            noise: Noise(amp: 0.28, tau: 0.0025, low: 1600, high: 4800), attack: 0.002),
        // Wood drawn in pixels: stiff harmonic partials, a grainy attack, no cavity.
        "pixel": Tone(
            bases: [604, 590, 618], length: 0.42, seed: 41,
            modes: [Mode(ratio: 1, amp: 0.90, tau: 0.050), Mode(ratio: 2, amp: 0.42, tau: 0.028),
                    Mode(ratio: 3, amp: 0.16, tau: 0.014), Mode(ratio: 4, amp: 0.06, tau: 0.008)],
            noise: Noise(amp: 0.7, tau: 0.003, low: 2000, high: 7000), attack: 0.0004, crush: true),
        // Solid jade, closer to a stone chime than to a hollow block.
        "jade": Tone(
            bases: [740, 724, 758], length: 0.85, seed: 53,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.16), Mode(ratio: 2.27, amp: 0.40, tau: 0.07),
                    Mode(ratio: 3.70, amp: 0.18, tau: 0.030), Mode(ratio: 6.40, amp: 0.10, tau: 0.010)],
            body: Mode(ratio: 0.72, amp: 0.06, tau: 0.04),
            noise: Noise(amp: 0.28, tau: 0.0011, low: 4500, high: 12000), attack: 0.0004),
        // A struck bronze bowl. The hum sits under a slightly sharp rim tone;
        // the cents are the slow beat of a bowl that isn't perfectly round.
        "bowl": Tone(
            bases: [196, 191, 202], length: 1.35, seed: 67,
            modes: [Mode(ratio: 1, amp: 0.62, tau: 0.70, cents: 5), Mode(ratio: 2.05, amp: 1, tau: 0.42, cents: 8),
                    Mode(ratio: 2.98, amp: 0.36, tau: 0.18, cents: 10), Mode(ratio: 5.10, amp: 0.14, tau: 0.07, cents: 14),
                    Mode(ratio: 9.40, amp: 0.16, tau: 0.014), Mode(ratio: 14.5, amp: 0.08, tau: 0.007)],
            noise: Noise(amp: 0.22, tau: 0.0018, low: 3200, high: 9000), attack: 0.0016),
        // A key bottoming out: a low plastic thud and a short bright click.
        "key": Tone(
            bases: [360, 348, 372], length: 0.22, seed: 79,
            modes: [Mode(ratio: 1, amp: 0.35, tau: 0.018), Mode(ratio: 4.2, amp: 0.70, tau: 0.010),
                    Mode(ratio: 7.5, amp: 0.22, tau: 0.005)],
            noise: Noise(amp: 0.85, tau: 0.0014, low: 2800, high: 9000), attack: 0.0003),
        // A hollow bamboo tube, more air than wood.
        "bamboo": Tone(
            bases: [262, 254, 270], length: 0.85, seed: 83,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.12), Mode(ratio: 2.76, amp: 0.38, tau: 0.05),
                    Mode(ratio: 4.4, amp: 0.12, tau: 0.025)],
            body: Mode(ratio: 0.5, amp: 0.65, tau: 0.22),
            noise: Noise(amp: 0.25, tau: 0.004, low: 800, high: 3200), attack: 0.0012),
        // Mossy stone: dull, gritty, the ring soaked up.
        "stone": Tone(
            bases: [340, 330, 350], length: 0.5, seed: 89,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.06), Mode(ratio: 1.7, amp: 0.30, tau: 0.03),
                    Mode(ratio: 2.6, amp: 0.12, tau: 0.015)],
            noise: Noise(amp: 0.55, tau: 0.006, low: 400, high: 2200), attack: 0.001, lowpass: 2000),
        // Steel on steel. A short clack, not a bowl's ring.
        "piston": Tone(
            bases: [510, 496, 524], length: 0.38, seed: 97,
            modes: [Mode(ratio: 1, amp: 0.45, tau: 0.028), Mode(ratio: 2.8, amp: 0.85, tau: 0.04),
                    Mode(ratio: 5.1, amp: 0.28, tau: 0.016), Mode(ratio: 8.4, amp: 0.10, tau: 0.007)],
            noise: Noise(amp: 0.35, tau: 0.0012, low: 3500, high: 10000), attack: 0.0003),
        // A plastic case, and a faint tick as the screen flashes.
        "crt": Tone(
            bases: [210, 204, 216], length: 0.4, seed: 101,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.05), Mode(ratio: 2.1, amp: 0.18, tau: 0.02)],
            noise: Noise(amp: 0.28, tau: 0.008, low: 200, high: 900), attack: 0.002, lowpass: 1100, crush: true),
    ]

    private static func strike(_ tone: Tone, base: Float, seed: UInt64) -> [Float] {
        var rng = Rng(seed)
        let n = Int(tone.length * sampleRate)
        var out = [Float](repeating: 0, count: n)
        let twoPi = 2 * Float.pi
        func add(_ ratio: Float, _ amp: Float, _ tau: Float, _ cents: Float, jitter: Bool) {
            var f = base * ratio
            if jitter { f *= 1 + rng.gaussian() * 0.004 }
            let phase0 = rng.unit() * twoPi
            oscillate(freq: f, amp: amp, tau: tau, phase: phase0)
            // A fixed offset, not a second random phase: a random one sometimes
            // starts in the null and the knock is a different note.
            if cents != 0 {
                oscillate(freq: f * pow(2 as Float, cents / 1200), amp: amp * 0.35, tau: tau, phase: phase0 + .pi / 2)
            }
        }
        func oscillate(freq: Float, amp: Float, tau: Float, phase: Float) {
            var phase = phase
            let dp = twoPi * freq / sampleRate
            let decay = exp(-1 / (tau * sampleRate))
            var env = amp
            for i in 0..<n {
                out[i] += env * sin(phase)
                phase += dp
                if phase > twoPi { phase -= twoPi }
                env *= decay
            }
        }
        for mode in tone.modes { add(mode.ratio, mode.amp, mode.tau, mode.cents, jitter: true) }
        if let body = tone.body { add(body.ratio, body.amp, body.tau, 0, jitter: false) }
        if let noise = tone.noise {
            var burst = [Float](repeating: 0, count: n)
            let decay = exp(-1 / (noise.tau * sampleRate))
            var env: Float = 1
            for i in 0..<n {
                burst[i] = rng.gaussian() * env
                env *= decay
            }
            var band = Biquad.bandpass(low: noise.low, high: noise.high)
            for i in 0..<n { out[i] += noise.amp * band.apply(burst[i]) }
        }
        let attackSamples = max(tone.attack * sampleRate, 1)
        for i in 0..<min(n, Int(attackSamples)) { out[i] *= Float(i) / attackSamples }
        let fade = min(n, Int(0.05 * sampleRate))
        if fade > 1 {
            for i in 0..<fade { out[n - fade + i] *= 1 - Float(i) / Float(fade - 1) }
        }
        if let hz = tone.lowpass {
            var filter = Biquad.lowpass(hz: hz)
            for i in 0..<n { out[i] = filter.apply(out[i]) }
        }
        if tone.crush {
            // A short sample-held tick on the attack, not a crushed tone.
            var tick = Rng(seed &+ 9)
            let m = Int(0.012 * sampleRate)
            let step = max(Int(sampleRate / 6000), 1)
            var held: Float = 0
            for i in 0..<min(m, n) {
                if i % step == 0 { held = (tick.unit() * 2 - 1) * exp(-Float(i) / (0.003 * sampleRate)) }
                out[i] += held * 0.22
            }
        }
        return level(out)
    }

    /// Match the wooden knock's attack loudness, without a click taking the whole peak.
    private static func level(_ x: [Float], attackRMS: Float = 0.23, peak: Float = 0.85) -> [Float] {
        let n = min(x.count, Int(0.15 * sampleRate))
        guard n > 0, let peak0 = x.max(by: { abs($0) < abs($1) }).map(abs), peak0 > 1e-8 else { return x }
        let unit = x.map { $0 / peak0 }
        var last = unit
        for drive in [Float(1), 1.6, 2.4] {
            let z: [Float]
            if drive == 1 {
                z = unit
            } else {
                let s = tanh(drive)
                z = unit.map { tanh($0 * drive) / s }
            }
            var acc: Float = 0
            for i in 0..<n { acc += z[i] * z[i] }
            let g = attackRMS / max(sqrt(acc / Float(n)), 1e-8)
            last = z.map { $0 * g }
            let p = last.max(by: { abs($0) < abs($1) }).map(abs) ?? 0
            if p <= peak { return last }
            if drive == 2.4, p > 0 { return last.map { $0 * peak / p } }
        }
        return last
    }

    /// One large wooden hall. Every voice is heard in it; the app mixes more of
    /// the tail in the longer the quiet before a knock.
    private enum Hall {
        static let length: Float = 3
        static let directToHall: Float = 2

        static func render(_ dry: [Float]) -> (left: [Float], right: [Float]) {
            let sr = KnockSynth.sampleRate
            let n = Int(length * sr)
            var left = [Float](repeating: 0, count: n)
            var right = [Float](repeating: 0, count: n)
            // Early reflections off the floor, pillars and walls. No direct sound:
            // that is the dry knock, played beside this.
            let taps: [(Float, Float, Float)] = [
                (13, 0.28, -0.55), (19, 0.24, 0.40), (27, 0.20, -0.25),
                (34, 0.16, 0.50), (46, 0.13, -0.15), (58, 0.10, 0.30), (71, 0.08, -0.40),
            ]
            for (ms, gain, pan) in taps {
                let d = Int(ms / 1000 * sr)
                guard d < n else { continue }
                let lGain = gain * sqrt((1 - pan) / 2)
                let rGain = gain * sqrt((1 + pan) / 2)
                let count = min(dry.count, n - d)
                for i in 0..<count {
                    left[i + d] += dry[i] * lGain
                    right[i + d] += dry[i] * rGain
                }
            }
            let delays: [Float] = [47, 53, 59, 67, 73, 83, 89, 97]
            var combsL = delays.map { Comb(ms: $0, rt60: 2.3, damp: 0.42) }
            var combsR = delays.map { Comb(ms: $0 + 1.7, rt60: 2.3, damp: 0.42) }
            var allL = [Allpass(ms: 5.1), Allpass(ms: 1.7)]
            var allR = [Allpass(ms: 6.3), Allpass(ms: 2.3)]
            let pre = Int(0.02 * sr)
            for i in 0..<n {
                let x = i >= pre && i - pre < dry.count ? dry[i - pre] : 0
                var l: Float = 0
                var r: Float = 0
                for c in combsL.indices {
                    l += combsL[c].process(x)
                    r += combsR[c].process(x)
                }
                l *= 0.15
                r *= 0.15
                for a in allL.indices {
                    l = allL[a].process(l)
                    r = allR[a].process(r)
                }
                left[i] += l
                right[i] += r
            }
            let fade = Int(0.4 * sr)
            for i in 0..<fade {
                let g = pow(1 - Float(i) / Float(fade), 2)
                left[n - fade + i] *= g
                right[n - fade + i] *= g
            }
            var dryE: Float = 0
            for s in dry { dryE += s * s }
            dryE /= sr
            var hallE: Float = 0
            for i in 0..<n { hallE += left[i] * left[i] + right[i] * right[i] }
            hallE /= 2 * sr
            guard hallE > 1e-8, dryE > 1e-8 else { return (left, right) }
            var g = sqrt(dryE / directToHall / hallE)
            var peak: Float = 0
            for i in 0..<n { peak = max(peak, abs(left[i] * g), abs(right[i] * g)) }
            if peak > 0.4 { g *= 0.4 / peak }
            for i in 0..<n {
                left[i] *= g
                right[i] *= g
            }
            return (left, right)
        }
    }

    private struct Comb {
        var buf: [Float]
        var index = 0
        var filter: Float = 0
        let feedback: Float
        let damp: Float

        init(ms: Float, rt60: Float, damp: Float) {
            let delay = max(Int(ms / 1000 * KnockSynth.sampleRate), 1)
            buf = [Float](repeating: 0, count: delay)
            feedback = exp(-6.91 * (Float(delay) / KnockSynth.sampleRate) / rt60)
            self.damp = damp
        }

        mutating func process(_ x: Float) -> Float {
            let y = buf[index]
            filter = y * (1 - damp) + filter * damp
            buf[index] = x + filter * feedback
            index += 1
            if index == buf.count { index = 0 }
            return y
        }
    }

    private struct Allpass {
        var buf: [Float]
        var index = 0
        let feedback: Float = 0.5

        init(ms: Float) {
            buf = [Float](repeating: 0, count: max(Int(ms / 1000 * KnockSynth.sampleRate), 1))
        }

        mutating func process(_ x: Float) -> Float {
            let delayed = buf[index]
            buf[index] = x + delayed * feedback
            index += 1
            if index == buf.count { index = 0 }
            return delayed - feedback * x
        }
    }

    private struct Biquad {
        var b0, b1, b2, a1, a2: Float
        var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0

        static func bandpass(low: Float, high: Float) -> Biquad {
            let f0 = sqrt(low * high)
            let q = max(f0 / (high - low), 0.15)
            return coefficients(f0: f0, q: q, band: true)
        }

        static func lowpass(hz: Float) -> Biquad {
            coefficients(f0: hz, q: 0.707, band: false)
        }

        private static func coefficients(f0: Float, q: Float, band: Bool) -> Biquad {
            let w0 = 2 * Float.pi * f0 / KnockSynth.sampleRate
            let alpha = sin(w0) / (2 * q)
            let cosw = cos(w0)
            let a0 = 1 + alpha
            if band {
                return Biquad(b0: alpha / a0, b1: 0, b2: -alpha / a0, a1: -2 * cosw / a0, a2: (1 - alpha) / a0)
            }
            let b = (1 - cosw) / 2 / a0
            return Biquad(b0: b, b1: (1 - cosw) / a0, b2: b, a1: -2 * cosw / a0, a2: (1 - alpha) / a0)
        }

        mutating func apply(_ x: Float) -> Float {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return y
        }
    }

    /// A small seeded generator, so a voice sounds the same each time it is prepared.
    private struct Rng {
        var state: UInt64
        init(_ seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }

        mutating func unit() -> Float { Float(next() >> 40) / 16777216 }

        mutating func gaussian() -> Float {
            let u1 = max(unit(), 1e-7)
            let u2 = unit()
            return sqrt(-2 * log(u1)) * cos(2 * Float.pi * u2)
        }
    }
}
