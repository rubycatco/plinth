import Foundation

/// The knock, synthesized as the mallet falls. A few decaying modes, a short
/// mallet burst, and one wooden hall they all ring in. Nothing is stored: a
/// skin names a voice, and the voice is a handful of numbers.
enum KnockSynth {
    static let sampleRate: Float = 44100
    static let voices = ["wood", "lacquer", "ink", "cartoon", "pixel", "jade", "bowl", "key", "bamboo", "stone", "piston", "crt", "bead", "plate", "porcelain", "bell", "stamp", "chime", "board", "ceramic", "temple"]

    /// The force every voice is tuned at, and that tools/knock_synth.py renders.
    static let referenceForce: Float = 0.6

    static func resolve(_ name: String?) -> String {
        guard let name, tones[name] != nil else { return "wood" }
        return name
    }

    /// One strike of `name`, never quite the last one. `force` runs from a
    /// brush (0) to a full blow (1); `place` from -1 to 1 is how far off the
    /// sweet spot the mallet lands. A harder blow is louder and brighter, a
    /// soft one rounder; off the spot the hollow speaks less and the shell more.
    /// `warmth` is the hour and the season, as `warmth(at:)` gives it.
    /// `settling` is how much a run of hurried keys softens the hand (0...1).
    static func knock(_ name: String, force: Float, place: Float, warmth: Float = 0, settling: Float = 0) -> [Float] {
        let settling = min(max(settling, 0), 1)
        let force = force * (1 - 0.35 * settling)
        let tone = tones[resolve(name)]!
        let base = tone.bases.randomElement()! * .random(in: 0.98...1.02)
        var out = strike(tone, base: base, seed: .random(in: 1...UInt64.max), force: force, place: place, warmth: warmth)
        if settling > 0 {
            // After levelling, so neither normalization nor a crushed attack
            // brings the highs back. The voice keeps its pitch and its body.
            var filter = Biquad.lowpass(hz: 7000 * pow(0.2, settling))
            for i in out.indices { out[i] = filter.apply(out[i]) }
        }
        let loud = pow(max(force, 0.05) / referenceForce, 0.8)
        return out.map { $0 * loud }
    }

    /// The voice's strike at the reference force, to tune the hall against.
    /// It is heard at no hour: its warmth is 0, the voice as tuned.
    static func reference(_ name: String) -> [Float] {
        let tone = tones[resolve(name)]!
        return strike(tone, base: tone.bases[0], seed: tone.seed)
    }

    /// How the hour and the season temper the wood and the hall it rings in:
    /// -1 the thin, cold air of the morning board (早板) at four on a winter's
    /// dawn, clear and a little bright; 1 the close, warm air of a summer's
    /// late night, the wood rounder and the hall softer. 0 is the voice as
    /// tuned. It moves so slowly that no knock sounds unlike the one before.
    static func warmth(at date: Date, calendar: Calendar = .current) -> Float {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Float(c.hour ?? 12) + Float(c.minute ?? 0) / 60 + Float(c.second ?? 0) / 3600
        // The day: clearest at the morning board, warming through the day and
        // the evening board (晚板) into the night, and turning back before dawn.
        let day: [(hour: Float, warmth: Float)] = [(0, 1), (4, -1), (8, -0.5), (13, 0), (18, 0.5), (21, 0.85), (24, 1)]
        var daily: Float = 1
        for (a, b) in zip(day, day.dropFirst()) where hour < b.hour {
            let t = (hour - a.hour) / (b.hour - a.hour)
            daily = a.warmth + (b.warmth - a.warmth) * t * t * (3 - 2 * t)
            break
        }
        // The year, by the sun rather than the calendar: coldest about 大寒, a
        // month after the winter solstice of 2000, and warmest about 大暑.
        let year = 365.2422 * 86400
        let greatCold = 977_405_820 + 30 * 86400.0
        let seasonal = Float(-cos(2 * Double.pi * (date.timeIntervalSince1970 - greatCold) / year))
        return min(max(0.7 * daily + 0.3 * seasonal, -1), 1)
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
            bases: [196, 191, 202], length: 3.0, seed: 67,
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
            bases: [262, 254, 270], length: 0.95, seed: 83,
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
        // Rosewood beads knocked together: small, dense, a dry clack with no hollow.
        "bead": Tone(
            bases: [1050, 1030, 1072], length: 0.3, seed: 103,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.030), Mode(ratio: 2.71, amp: 0.42, tau: 0.016),
                    Mode(ratio: 5.2, amp: 0.16, tau: 0.007)],
            body: Mode(ratio: 0.42, amp: 0.10, tau: 0.03),
            noise: Noise(amp: 0.55, tau: 0.0016, low: 2500, high: 8000), attack: 0.0004),
        // A flat bronze plate under a leather mallet. A plate's partials don't line
        // up the way a bowl's do, and the soft head keeps the clang out.
        "plate": Tone(
            bases: [330, 322, 338], length: 2.2, seed: 107,
            modes: [Mode(ratio: 1, amp: 0.8, tau: 0.55, cents: 6), Mode(ratio: 1.59, amp: 1, tau: 0.38, cents: 9),
                    Mode(ratio: 2.14, amp: 0.55, tau: 0.22, cents: 12), Mode(ratio: 2.65, amp: 0.30, tau: 0.12),
                    Mode(ratio: 3.61, amp: 0.14, tau: 0.06)],
            noise: Noise(amp: 0.18, tau: 0.003, low: 600, high: 2800), attack: 0.002, lowpass: 5000),
        // Thin glazed porcelain: high, bright and clean, a short ring.
        "porcelain": Tone(
            bases: [1180, 1160, 1204], length: 0.7, seed: 109,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.14), Mode(ratio: 2.32, amp: 0.36, tau: 0.06),
                    Mode(ratio: 4.1, amp: 0.16, tau: 0.024), Mode(ratio: 6.9, amp: 0.08, tau: 0.009)],
            noise: Noise(amp: 0.30, tau: 0.0008, low: 5000, high: 13000), attack: 0.0003),
        // An almond-shaped bronze bell: two notes a minor third apart, struck with
        // wood, and damped sooner than a round bell would be.
        "bell": Tone(
            bases: [392, 384, 400], length: 2.0, seed: 113,
            modes: [Mode(ratio: 0.5, amp: 0.30, tau: 0.50), Mode(ratio: 1, amp: 1, tau: 0.40, cents: 4),
                    Mode(ratio: 1.19, amp: 0.65, tau: 0.32), Mode(ratio: 2.4, amp: 0.35, tau: 0.12),
                    Mode(ratio: 3.1, amp: 0.20, tau: 0.06), Mode(ratio: 4.9, amp: 0.10, tau: 0.03)],
            noise: Noise(amp: 0.25, tau: 0.002, low: 800, high: 4000), attack: 0.001),
        // A stone seal pressed onto paper: a short, dull thud.
        "stamp": Tone(
            bases: [180, 172, 188], length: 0.3, seed: 127,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.030), Mode(ratio: 2.3, amp: 0.35, tau: 0.015),
                    Mode(ratio: 3.9, amp: 0.12, tau: 0.008)],
            body: Mode(ratio: 0.6, amp: 0.40, tau: 0.04),
            noise: Noise(amp: 0.60, tau: 0.006, low: 300, high: 2500), attack: 0.001, lowpass: 2500),
        // A thin slab of stone hung on a cord. It rings longer than the jade fish,
        // and the felt mallet keeps the attack soft.
        "chime": Tone(
            bases: [560, 548, 574], length: 1.7, seed: 131,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.35), Mode(ratio: 2.76, amp: 0.45, tau: 0.14),
                    Mode(ratio: 5.4, amp: 0.20, tau: 0.05), Mode(ratio: 8.9, amp: 0.08, tau: 0.015)],
            noise: Noise(amp: 0.15, tau: 0.003, low: 1000, high: 5000), attack: 0.0015),
        // The long wooden fish that hangs outside the hall: lower than the
        // wooden fish, and longer.
        "board": Tone(
            bases: [430, 420, 442], length: 0.95, seed: 137,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.13), Mode(ratio: 1.58, amp: 0.50, tau: 0.08),
                    Mode(ratio: 2.42, amp: 0.28, tau: 0.05), Mode(ratio: 3.3, amp: 0.14, tau: 0.03)],
            body: Mode(ratio: 0.5, amp: 0.45, tau: 0.18),
            noise: Noise(amp: 0.55, tau: 0.004, low: 1200, high: 6000), attack: 0.001),
        // A spoon on the rim of a full mug: a bright ting, damped by the coffee.
        "ceramic": Tone(
            bases: [1450, 1420, 1480], length: 0.5, seed: 139,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.09), Mode(ratio: 2.1, amp: 0.45, tau: 0.05),
                    Mode(ratio: 3.5, amp: 0.25, tau: 0.02), Mode(ratio: 5.6, amp: 0.10, tau: 0.01)],
            body: Mode(ratio: 0.35, amp: 0.15, tau: 0.05),
            noise: Noise(amp: 0.45, tau: 0.0007, low: 5000, high: 14000), attack: 0.0002),
        // A big old temple fish under a cloth-wrapped mallet: the lowest of the
        // wooden fishes, a long hollow ring, and a soft dok where the click was.
        "temple": Tone(
            bases: [370, 361, 380], length: 1.2, seed: 149,
            modes: [Mode(ratio: 1, amp: 1, tau: 0.17), Mode(ratio: 1.52, amp: 0.45, tau: 0.10),
                    Mode(ratio: 2.31, amp: 0.22, tau: 0.055), Mode(ratio: 3.07, amp: 0.10, tau: 0.032)],
            body: Mode(ratio: 0.5, amp: 0.65, tau: 0.30),
            noise: Noise(amp: 1.0, tau: 0.005, low: 800, high: 3500), attack: 0.002, lowpass: 4500),
    ]

    private static func strike(_ tone: Tone, base: Float, seed: UInt64,
                               force: Float = referenceForce, place: Float = 0, warmth: Float = 0) -> [Float] {
        var rng = Rng(seed)
        let n = Int(tone.length * sampleRate)
        var out = [Float](repeating: 0, count: n)
        let twoPi = 2 * Float.pi
        // Both are 1 at the reference force, on the sweet spot.
        let hard = max(force, 0.05) / referenceForce
        let edge = min(abs(place), 1)
        // A harder blow pulls the pitch up a hair; the thinner lip is a little higher.
        let base = base * (1 + 0.004 * (force - referenceForce)) * (1 + 0.012 * edge)
        // Warm, close air, and wood that has taken some of it in: the hollow
        // speaks a little longer, and the upper modes a little less and briefer.
        // Cold, dry air the other way. All of it is 1 at warmth 0.
        let w = min(max(warmth, -1), 1)
        // After the evening board, soften further into the deep night, without
        // a step at 0.7. The morning's shorter contact stays clear and crisp.
        let late = max((w - 0.7) / 0.3, 0)
        let night = late * late * (3 - 2 * late)
        func add(_ ratio: Float, _ amp: Float, _ tau: Float, _ cents: Float, jitter: Bool, body: Bool = false) {
            // A harder blow is a shorter contact, which reaches the higher modes.
            var amp = amp * pow(hard, 0.6 * log2(max(ratio, 0.25)))
            if body { amp *= 1 - 0.4 * edge } else if ratio == 1 { amp *= 1 - 0.3 * edge } else if ratio > 1 { amp *= 1 + 0.5 * edge }
            var tau = tau
            if body {
                amp *= 1 + 0.20 * w + 0.10 * night
                tau *= 1 + 0.10 * w + 0.04 * night
            } else if ratio > 1 {
                amp *= pow(ratio, -0.18 * w - 0.12 * night)
                tau *= pow(ratio, -0.07 * w - 0.04 * night)
            }
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
        if let body = tone.body { add(body.ratio, body.amp, body.tau, 0, jitter: false, body: true) }
        if var noise = tone.noise {
            // The mallet's own click: louder and higher the harder it lands.
            noise.amp *= pow(hard, 1.2)
            noise.low *= pow(hard, 0.2)
            noise.high = min(noise.high * pow(hard, 0.4), 0.45 * sampleRate)
            // A dull, warm room takes the edge off the click; a cold one sharpens it.
            noise.amp *= pow(2, -0.32 * w - 0.32 * night)
            noise.low *= pow(2, -0.16 * w - 0.14 * night)
            noise.high = min(noise.high * pow(2, -0.28 * w - 0.20 * night), 0.45 * sampleRate)
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
        let contact = pow(2, 0.45 * w + 0.50 * night)
        let attackSamples = max(tone.attack * pow(1 / hard, 0.7) * contact * sampleRate, 1)
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
                // This tick is added after the envelope: it must soften too,
                // rather than bringing back a hard edge at night.
                let edge = 1 - max(w, 0) * (1 - min(Float(i) / attackSamples, 1))
                out[i] += held * 0.22 * (1 - 0.22 * w - 0.22 * night) * edge
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

    /// One wooden room, from a small meditation room to a large hall. Every
    /// voice is heard in it; the app mixes more of the tail in the longer the
    /// quiet before a knock.
    enum Hall {
        /// The hall the knocks have always rung in, and tools/knock_synth.py renders.
        static let defaultSpace: Float = 0.7

        /// How much of its highs the hall's wood soaks up on each pass, at a
        /// `KnockSynth.warmth`: a little less in cold dry air, a little more in
        /// warm close air. 0.42 at warmth 0, the hall as tuned.
        static func damp(warmth: Float) -> Float {
            0.42 + 0.06 * min(max(warmth, -1), 1)
        }

        /// The room at `space`: 0 a small meditation room (禅房), `defaultSpace`
        /// a large hall, 1 a larger one (大殿). `size` scales its reflections'
        /// distances, `rt60` is how long its tail rings, and `directToHall` how
        /// much quieter that tail is than the knock.
        static func shape(_ space: Float) -> (size: Float, rt60: Float, directToHall: Float) {
            let s = min(max(space, 0), 1)
            // Interpolate from the default up or down, so the default is exact.
            if s >= defaultSpace {
                let t = (s - defaultSpace) / (1 - defaultSpace)
                return (1 + 0.3 * t, 2.3 + 1.3 * t, 2 - 0.4 * t)
            }
            let t = (defaultSpace - s) / defaultSpace
            return (1 - 0.65 * t, 2.3 - 1.85 * t, 2 + 3 * t)
        }

        /// The hall as a stream: every knock goes into the same room, so a run
        /// of knocks rings together rather than each in a room of its own.
        struct Room {
            let rt60: Float
            // The dry signal's recent past, for the early reflections and the pre-delay.
            private var line: [Float]
            private var write = 0
            private let taps: [(delay: Int, left: Float, right: Float)]
            private let pre: Int
            private var combsL: [Comb]
            private var combsR: [Comb]
            private var allL = [Allpass(ms: 5.1), Allpass(ms: 1.7)]
            private var allR = [Allpass(ms: 6.3), Allpass(ms: 2.3)]

            init(space: Float, damp: Float = Hall.damp(warmth: 0)) {
                let (size, rt60, _) = shape(space)
                let sr = KnockSynth.sampleRate
                self.rt60 = rt60
                // Early reflections off the floor, pillars and walls. No direct
                // sound: that is the dry knock, heard beside this.
                let early: [(Float, Float, Float)] = [
                    (13, 0.28, -0.55), (19, 0.24, 0.40), (27, 0.20, -0.25),
                    (34, 0.16, 0.50), (46, 0.13, -0.15), (58, 0.10, 0.30), (71, 0.08, -0.40),
                ]
                taps = early.map { ms, gain, pan in
                    (Int(ms * size / 1000 * sr), gain * sqrt((1 - pan) / 2), gain * sqrt((1 + pan) / 2))
                }
                pre = Int(0.02 * size * sr)
                line = [Float](repeating: 0, count: max(taps.map(\.delay).max() ?? 0, pre) + 1)
                let delays: [Float] = [47, 53, 59, 67, 73, 83, 89, 97]
                combsL = delays.map { Comb(ms: $0 * size, rt60: rt60, damp: damp) }
                combsR = delays.map { Comb(ms: ($0 + 1.7) * size, rt60: rt60, damp: damp) }
            }

            /// The hall's damping, as `Hall.damp(warmth:)`. It can change as
            /// the room rings, so the tail carries on.
            var damp: Float {
                get { combsL[0].damp }
                set {
                    for c in combsL.indices {
                        combsL[c].damp = newValue
                        combsR[c].damp = newValue
                    }
                }
            }

            /// How long a knock rings on in this room.
            var tail: Double { Double(max(rt60 + 0.7, 0.8)) }

            mutating func process(_ x: Float) -> (left: Float, right: Float) {
                let n = line.count
                line[write] = x
                var l: Float = 0
                var r: Float = 0
                for tap in taps {
                    let v = line[(write - tap.delay + n) % n]
                    l += v * tap.left
                    r += v * tap.right
                }
                let delayed = line[(write - pre + n) % n]
                write = (write + 1) % n
                var cl: Float = 0
                var cr: Float = 0
                for c in combsL.indices {
                    cl += combsL[c].process(delayed)
                    cr += combsR[c].process(delayed)
                }
                cl *= 0.15
                cr *= 0.15
                for a in allL.indices {
                    cl = allL[a].process(cl)
                    cr = allR[a].process(cr)
                }
                return (l + cl, r + cr)
            }
        }

        /// The gain that sets `room`'s tail to `directToHall` below the dry knock
        /// `dry`, with its loudest moment kept well under the knock's.
        static func gain(for dry: [Float], space: Float) -> Float {
            var room = Room(space: space)
            let directToHall = shape(space).directToHall
            let n = Int(room.tail * Double(KnockSynth.sampleRate))
            var dryE: Float = 0
            for s in dry { dryE += s * s }
            var hallE: Float = 0
            var peak: Float = 0
            for i in 0..<n {
                let (l, r) = room.process(i < dry.count ? dry[i] : 0)
                hallE += (l * l + r * r) / 2
                peak = max(peak, abs(l), abs(r))
            }
            guard hallE > 1e-8, dryE > 1e-8 else { return 0 }
            let g = sqrt(dryE / directToHall / hallE)
            return peak * g > 0.4 ? 0.4 / peak : g
        }
    }

    private struct Comb {
        var buf: [Float]
        var index = 0
        var filter: Float = 0
        let feedback: Float
        var damp: Float

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
