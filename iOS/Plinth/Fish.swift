import AVFoundation
import Observation
import PlinthCore

/// The fish on the iPhone: knocked by a finger, heard through the speaker or
/// headphones, and felt in the hand. As on the Mac, it starts in ink.
@MainActor @Observable
final class Fish {
    let pack: SkinPack
    /// The mallet's latest swing; each new one swings it again.
    private(set) var swing = Swing()
    /// Counts the moments the mallet meets the figure. Nothing else is
    /// counted: knocking earns no merit.
    private(set) var impacts = 0
    /// How fully the last knock rang: 0 after a rushed knock, 1 after a long quiet.
    private(set) var bloom = 1.0
    @ObservationIgnored private let sound = KnockSound(headphones: Headphones.inUse)
    @ObservationIgnored private let haptics = KnockHaptics()
    /// When the mallet last met the wood, on the system uptime clock.
    @ObservationIgnored private var lastImpact = -Double.infinity

    init() {
        // Ambient audio keeps to the Ring/Silent switch and plays along with
        // other apps' audio. Switched to silent, the fish is felt, not heard.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        pack = SkinPack.load(Bundle.main.url(forResource: "Skins", withExtension: nil)?.appending(path: "ink-fish"))
            ?? SkinPack(idle: SkinImage())
        sound.use(voice: pack.voice, space: KnockSynth.Hall.defaultSpace)
    }

    /// Knock once, where the finger went down across the fish: 0 at its left
    /// edge, 1 at its right. After a long quiet, the mallet rests on the wood
    /// before it lifts (压槌).
    func knock(at x: Double) {
        let rested = KnockSound.bloom(afterSilence: ProcessInfo.processInfo.systemUptime + Swing.impactDelay - lastImpact)
        swing = Swing(serial: swing.serial + 1, lingers: rested > 0.9)
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
