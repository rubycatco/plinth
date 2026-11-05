import AVFoundation
import os

/// The worn skin's knock and the room it rings in. Each knock is synthesized
/// as the mallet falls, for how hard and where it lands, and for the hour and
/// the season. It comes from where the fish sits, placed around the listener,
/// and on headphones it is rendered for the ears, and stays where the fish
/// sits as the head turns. Every knock rings in the one hall, so a run of
/// knocks builds up in the room the way it would in a temple, rather than
/// each in its own.
///
/// The engine runs only while a knock rings. A running engine holds the audio
/// output open, which keeps the Mac from idle sleep and costs CPU even in silence.
@MainActor
public final class KnockSound {
    /// How long the engine stays up after the last knock has rung out, so a
    /// run of knocks doesn't start it again for each one.
    private static let linger = 2.0

    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private let mix = KnockMix()
    private let dry: AVAudioSourceNode
    private let hall: AVAudioSourceNode
    private var voice = ""
    private var space: Float = -1
    private var tail = 3.0
    /// The hour and the season the last knock was made in.
    private var warmth: Float = 0
    private var ringsUntil = 0.0
    private var quiet: Task<Void, Never>?
    /// Where the fish sits, from the middle of the main display, and whether
    /// the knock goes to headphones.
    private var spot: (across: Float, up: Float) = (0, 0)
    private var headphones = false
    /// Whether the output in use is headphones, as the platform can tell.
    private let headphonesInUse: () -> Bool

    public init(headphones: @escaping () -> Bool) {
        headphonesInUse = headphones
        let sr = Double(KnockSynth.sampleRate)
        let mono = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        let stereo = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
        let blocks = Self.renderers(mix)
        dry = AVAudioSourceNode(format: mono, renderBlock: blocks.dry)
        hall = AVAudioSourceNode(format: stereo, renderBlock: blocks.hall)
        for node in [dry, environment, hall] as [AVAudioNode] { engine.attach(node) }
        // The knock itself is a point in space; the hall is all around.
        engine.connect(dry, to: environment, format: mono)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
        engine.connect(hall, to: engine.mainMixerNode, format: stereo)
        environment.reverbParameters.enable = false
        dry.sourceMode = .pointSource
        dry.reverbBlend = 0
        route()
        engine.prepare()
    }

    /// The render blocks run on the audio thread, so they are made outside the main actor.
    private nonisolated static func renderers(_ mix: KnockMix) -> (dry: AVAudioSourceNodeRenderBlock, hall: AVAudioSourceNodeRenderBlock) {
        let dry: AVAudioSourceNodeRenderBlock = { _, _, frames, list in
            mix.renderDry(UnsafeMutableAudioBufferListPointer(list)[0], Int(frames))
            return noErr
        }
        let hall: AVAudioSourceNodeRenderBlock = { _, _, frames, list in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            mix.renderHall(buffers[0], buffers[1], Int(frames))
            return noErr
        }
        return (dry, hall)
    }

    /// Wear this voice, in a room of this size. Unknown names, and none, are
    /// the wooden fish.
    public func use(voice name: String?, space: Float) {
        let next = KnockSynth.resolve(name)
        guard next != voice || space != self.space else { return }
        // A new voice keeps the room ringing; only a new room starts it afresh.
        let room = space != self.space ? KnockSynth.Hall.Room(space: space, damp: KnockSynth.Hall.damp(warmth: warmth)) : nil
        voice = next
        self.space = space
        if let room { tail = room.tail }
        mix.use(room: room, gain: KnockSynth.Hall.gain(for: KnockSynth.reference(next), space: space))
    }

    /// Where the fish sits, from the middle of the main display, which is
    /// taken to be in front of you: `across` in its widths to the right, `up`
    /// in its heights. The displays stand in an arc around you, so the main
    /// display's edges are a little to either side and a display beside it
    /// further round. Knocks still ringing move with it.
    public func place(across: Float, up: Float) {
        spot = (across, up)
        // On headphones the knock is rendered for the ears, up and down as well
        // as across, the main display's edges 40° to either side and 15° up
        // or down. Speakers get a gentle pan: rendered for ears, a knock at the
        // screen's edge comes out of one speaker alone.
        let azimuth = headphones ? atan(2 * tan(0.7) * across) : min(max(0.5 * across, -0.35), 0.35)
        let elevation = headphones ? atan(2 * tan(0.26) * up) : 0
        dry.position = AVAudio3DPoint(x: sin(azimuth) * cos(elevation), y: sin(elevation),
                                      z: -cos(azimuth) * cos(elevation))
    }

    /// Render for the output in use. Checked as the engine starts, which it
    /// does after every quiet and after the output changes.
    private func route() {
        headphones = headphonesInUse()
        environment.outputType = headphones ? .headphones : .externalSpeakers
        dry.renderingAlgorithm = headphones ? .HRTFHQ : .equalPowerPanning
        place(across: spot.across, up: spot.up)
    }

    /// Start synthesizing one knock of the worn voice, or of `voice`, while the
    /// mallet falls, for the hour and the season, and temper the hall to match.
    public func synthesize(force: Float, place: Float, voice: String? = nil, settling: Float = 0) -> Task<[Float], Never> {
        let voice = voice ?? self.voice
        let warmth = KnockSynth.warmth(at: .now)
        if abs(warmth - self.warmth) > 0.005 {
            self.warmth = warmth
            mix.temper(damp: KnockSynth.Hall.damp(warmth: warmth))
        }
        return Task.detached(priority: .userInitiated) {
            KnockSynth.knock(voice, force: force, place: place, warmth: warmth, settling: settling)
        }
    }

    /// Start the engine, if it is paused, for a knock due in `seconds`.
    /// Starting it takes a moment, best spent while the mallet is in the air.
    public func warm(for seconds: Double) {
        guard start() else { return }
        ringsUntil = max(ringsUntil, ProcessInfo.processInfo.systemUptime + seconds)
        pauseWhenQuiet()
    }

    private func start() -> Bool {
        if engine.isRunning { return true }
        route()
        do { try engine.start() } catch { return false }
        return true
    }

    /// Play one knock. `bloom` (0...1) is how much of the hall rings with it;
    /// a rushed knock is also a little quieter. Even a rushed knock sends a
    /// little to the hall, so a run of them builds up in the room together.
    public func play(_ knock: [Float], volume: Float, bloom: Float, unseen: Bool = false) {
        guard knock.count > 1, volume > 0, start() else { return }
        let gain = volume * .random(in: 0.92...1.0)
        let balance = Self.balance(bloom: bloom, unseen: unseen)
        mix.add(knock, dry: gain * balance.dry, send: gain * balance.send)
        let now = ProcessInfo.processInfo.systemUptime
        let rings = Double(knock.count) / Double(KnockSynth.sampleRate) + tail
        ringsUntil = max(ringsUntil, now + rings)
        pauseWhenQuiet()
    }

    /// Without a visible fish, less of the point source and more of the hall,
    /// even in a run of knocks. Keep the chosen room and its ringing tail.
    static func balance(bloom: Float, unseen: Bool) -> (dry: Float, send: Float) {
        let bloom = min(max(bloom, 0), 1)
        return unseen ? (0.44 + 0.11 * bloom, 0.65 + 0.35 * bloom)
            : (0.8 + 0.2 * bloom, 0.25 + 0.75 * bloom)
    }

    /// Pause the engine once every knock has rung out, plus `linger`.
    private func pauseWhenQuiet() {
        quiet?.cancel()
        let wait = ringsUntil + Self.linger - ProcessInfo.processInfo.systemUptime
        quiet = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(wait, 0)))
            guard !Task.isCancelled, let self else { return }
            self.engine.pause()
        }
    }
}

/// The mix as the audio thread sees it. The main thread hands it knocks and
/// rooms through `inbox`, and takes back the knocks that have rung out; the
/// audio thread never allocates or frees.
private final class KnockMix: @unchecked Sendable {
    /// A knock's samples, owned by whichever side holds it; the inbox hands it over.
    struct Voice: @unchecked Sendable {
        var samples: UnsafeMutableBufferPointer<Float>
        var at = 0
        var dry: Float
        var send: Float
    }

    struct Inbox {
        var voices: [Voice] = []
        var spent: [Voice] = []
        var room: KnockSynth.Hall.Room?
        var gain: Float?
        var damp: Float?
        var oldRoom: KnockSynth.Hall.Room?
    }

    /// More knocks than this at once, and the newest is dropped.
    private static let capacity = 48

    private let inbox: OSAllocatedUnfairLock<Inbox>
    // The main thread's.
    private var alive = 0
    // The audio thread's.
    private var playing: [Voice] = []
    private var finished: [Voice] = []
    private var room = KnockSynth.Hall.Room(space: KnockSynth.Hall.defaultSpace)
    private var gain: Float = 0
    /// What the knocks send to the hall, from the dry render to the hall's.
    private var send = [Float](repeating: 0, count: 1 << 14)
    private var sent = 0
    private var heard = 0

    init() {
        var box = Inbox()
        box.voices.reserveCapacity(Self.capacity)
        box.spent.reserveCapacity(Self.capacity)
        inbox = OSAllocatedUnfairLock(initialState: box)
        playing.reserveCapacity(Self.capacity)
        finished.reserveCapacity(Self.capacity)
    }

    func use(room: KnockSynth.Hall.Room?, gain: Float) {
        // The room the audio thread let go of is freed here, outside the lock.
        _ = inbox.withLock { box in
            box.room = room ?? box.room
            box.gain = gain
            defer { box.oldRoom = nil }
            return box.oldRoom
        }
    }

    /// Change how much of its highs the hall soaks up, as it rings.
    func temper(damp: Float) {
        inbox.withLock { $0.damp = damp }
    }

    func add(_ knock: [Float], dry: Float, send: Float) {
        let (spent, _) = inbox.withLock { box in
            defer { box.spent.removeAll(keepingCapacity: true); box.oldRoom = nil }
            return (box.spent, box.oldRoom)
        }
        for voice in spent { voice.samples.deallocate() }
        alive -= spent.count
        guard alive < Self.capacity else { return }
        let samples = UnsafeMutableBufferPointer<Float>.allocate(capacity: knock.count)
        _ = samples.initialize(from: knock)
        alive += 1
        let voice = Voice(samples: samples, dry: dry, send: send)
        inbox.withLock { $0.voices.append(voice) }
    }

    func renderDry(_ buffer: AudioBuffer, _ frames: Int) {
        inbox.withLock { box in
            playing.append(contentsOf: box.voices)
            box.voices.removeAll(keepingCapacity: true)
            box.spent.append(contentsOf: finished)
            finished.removeAll(keepingCapacity: true)
        }
        guard let out = buffer.mData?.assumingMemoryBound(to: Float.self) else { return }
        let mask = send.count - 1
        for k in 0..<frames {
            out[k] = 0
            send[(sent + k) & mask] = 0
        }
        var i = 0
        while i < playing.count {
            let v = playing[i]
            let n = min(frames, v.samples.count - v.at)
            for k in 0..<n {
                let s = v.samples[v.at + k]
                out[k] += s * v.dry
                send[(sent + k) & mask] += s * v.send
            }
            if v.at + n >= v.samples.count {
                finished.append(v)
                playing.remove(at: i)
            } else {
                playing[i].at += n
                i += 1
            }
        }
        sent += frames
        for k in 0..<frames { out[k] = Self.soft(out[k]) }
    }

    func renderHall(_ left: AudioBuffer, _ right: AudioBuffer, _ frames: Int) {
        inbox.withLock { box in
            if var next = box.room {
                swap(&room, &next)
                box.oldRoom = next
                box.room = nil
            }
            if let g = box.gain {
                gain = g
                box.gain = nil
            }
            if let d = box.damp {
                room.damp = d
                box.damp = nil
            }
        }
        guard let l = left.mData?.assumingMemoryBound(to: Float.self),
              let r = right.mData?.assumingMemoryBound(to: Float.self) else { return }
        // The dry render may come before or after this one in a cycle; either
        // way the hall hears it at most one buffer late, a touch of pre-delay.
        if sent - heard > 2 * frames { heard = sent - frames }
        let ready = min(sent - heard, frames)
        let lead = frames - ready
        let mask = send.count - 1
        for k in 0..<frames {
            let x = k < lead ? 0 : send[(heard + k - lead) & mask]
            let (a, b) = room.process(x)
            l[k] = Self.soft(a * gain)
            r[k] = Self.soft(b * gain)
        }
        heard += ready
    }

    /// Leave the knock alone, and round off a pile of them before it clips.
    private static func soft(_ x: Float) -> Float {
        let a = abs(x)
        return a < 0.8 ? x : copysign(0.8 + 0.2 * tanh((a - 0.8) / 0.2), x)
    }
}
