import AVFoundation
import Observation
import PlinthCore

/// The fish on the iPhone: knocked by a finger, heard through the speaker or
/// headphones, and felt in the hand. As on the Mac, it starts in ink.
@MainActor @Observable
final class Fish {
    /// The worn skin's `SkinOption.id`, kept as the Mac keeps it. A skin is
    /// stored only once one is chosen; until then, the ink fish.
    var skin: String {
        didSet {
            UserDefaults.standard.set(skin, forKey: "skin")
            wear()
        }
    }
    private(set) var pack = SkinOption.inkFish.pack
    /// The mallet's latest swing; each new one swings it again.
    private(set) var swing = Swing()
    /// Counts the moments the mallet meets the figure. Nothing else is
    /// counted: knocking earns no merit.
    private(set) var impacts = 0
    /// How fully the last knock rang: 0 after a rushed knock, 1 after a long quiet.
    private(set) var bloom = 1.0
    /// The fish's line for the day, while it is said. The iPhone writes it on
    /// the page a half-open iPhone Duo spares, so the fish says it only there.
    private(set) var saying: Quote?
    @ObservationIgnored private var hush: Task<Void, Never>?
    @ObservationIgnored private let sound = KnockSound(headphones: Headphones.inUse)
    @ObservationIgnored private let haptics = KnockHaptics()
    /// When the mallet last met the wood, on the system uptime clock.
    @ObservationIgnored private var lastImpact = -Double.infinity

    init() {
        // Ambient audio keeps to the Ring/Silent switch and plays along with
        // other apps' audio. Switched to silent, the fish is felt, not heard.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        skin = UserDefaults.standard.string(forKey: "skin") ?? SkinOption.inkFish.id
        wear()
    }

    /// Put on the worn skin and its voice. A skin that no longer ships is the ink fish.
    private func wear() {
        pack = (SkinOption.builtIn.first { $0.id == skin } ?? SkinOption.inkFish).pack
        sound.use(voice: pack.voice, space: KnockSynth.Hall.defaultSpace)
    }

    /// Knock once, where the finger went down across the fish: 0 at its left
    /// edge, 1 at its right, or near the strike point when nothing says
    /// where. After a long quiet, the mallet rests on the wood before it
    /// lifts (压槌). A `preview`, to hear a skin just chosen, never rests.
    /// A knock that `speaks` says the fish's line for the day, if one is due,
    /// as the mallet lands.
    func knock(at x: Double? = nil, preview: Bool = false, speaks: Bool = false) {
        let rested = KnockSound.bloom(afterSilence: ProcessInfo.processInfo.systemUptime + Swing.impactDelay - lastImpact)
        swing = Swing(serial: swing.serial + 1, lingers: !preview && rested > 0.9)
        // Wake the audio, and make the knock, while the mallet is in the air.
        sound.warm(for: Swing.impactDelay)
        let force = Swing.force(rested: Float(rested))
        let place = Swing.place(at: x, strike: pack.strike.x)
        let knock = sound.synthesize(force: force, place: place)
        Task {
            try? await Task.sleep(for: .seconds(Swing.impactDelay))
            let samples = await knock.value
            let now = ProcessInfo.processInfo.systemUptime
            bloom = KnockSound.bloom(afterSilence: now - lastImpact)
            lastImpact = now
            impacts += 1
            sound.play(samples, volume: 0.8, bloom: Float(bloom))
            haptics.play(force: force, place: place, bloom: bloom)
            if speaks { speak() }
        }
    }

    /// As on the Mac, the fish has a few things to say and says each once:
    /// the next line, on the first knock by hand each day (from 4 a.m.). After
    /// the last, it only knocks. The words stay as long as the Mac's do.
    private func speak() {
        guard let quote = Zen.nextSaying() else { return }
        saying = quote
        hush?.cancel()
        hush = Task {
            try? await Task.sleep(for: .seconds(quote.readingTime))
            guard !Task.isCancelled else { return }
            saying = nil
        }
    }
}

/// Whether the knock goes to headphones, where it can be rendered for the
/// ears. Bluetooth outputs count, as most of them are earbuds and headphones.
enum Headphones {
    static func inUse() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            [.headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP].contains($0.portType)
        }
    }
}
