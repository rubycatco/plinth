import AppKit
import AVFoundation
import Observation
import ServiceManagement
import UniformTypeIdentifiers

enum Placement: String, CaseIterable, Identifiable {
    case floating, desktop
    var id: Self { self }
    var title: String {
        switch self {
        case .floating: String(localized: "Above windows")
        case .desktop: String(localized: "On the desktop")
        }
    }
}

enum FishSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: Self { self }
    var title: String {
        switch self {
        case .small: String(localized: "Small")
        case .medium: String(localized: "Medium")
        case .large: String(localized: "Large")
        }
    }
    var side: CGFloat {
        switch self {
        case .small: 150
        case .medium: 210
        case .large: 300
        }
    }
}

@MainActor @Observable
final class Fish {
    static let shared = Fish()

    /// Time from the start of the swing until the mallet meets the wood, and
    /// how much of it the small lift before the swing takes.
    static let impactDelay = 0.13
    static let liftDuration = 0.05
    /// A typed key gets a short, quick swing, so the knock keeps up with the hand.
    static let quickImpactDelay = 0.03

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let sound = KnockSound()
    @ObservationIgnored private let typing = TypingWatcher()
    @ObservationIgnored private var autoTask: Task<Void, Never>?
    @ObservationIgnored var onWindowChange: (() -> Void)?
    @ObservationIgnored private var skinWatcher: DispatchSourceFileSystemObject?
    @ObservationIgnored private var skinFileWatcher: DispatchSourceFileSystemObject?
    @ObservationIgnored private var skinRefresh: Task<Void, Never>?
    /// When the mallet last met the wood, on the system uptime clock.
    @ObservationIgnored private var lastImpact = -Double.infinity

    private(set) var strikes = 0
    /// Whether the latest swing is a quick one, for a typed key.
    private(set) var quickStrike = false
    /// Counts the moments the mallet meets the figure. Nothing else is
    /// counted: knocking earns no merit.
    private(set) var impacts = 0
    /// How fully the last knock rang: 0 after a rushed knock, 1 after a long quiet.
    private(set) var bloom = 1.0
    private(set) var notice: Quote?
    private var autoRound = 0

    var autoKnock: Bool {
        didSet { defaults.set(autoKnock, forKey: "autoKnock"); autoRound = 0; restartAuto() }
    }
    var interval: Double {
        didSet { defaults.set(interval, forKey: "interval"); restartAuto() }
    }
    var stopAt108: Bool { didSet { defaults.set(stopAt108, forKey: "stopAt108") } }
    /// Each key pressed in any app knocks once. Typed knocks are never answered.
    var knockAsYouType: Bool {
        didSet { defaults.set(knockAsYouType, forKey: "knockAsYouType"); watchTyping() }
    }
    var volume: Double { didSet { defaults.set(volume, forKey: "volume") } }
    var size: FishSize {
        didSet { defaults.set(size.rawValue, forKey: "size"); onWindowChange?() }
    }
    /// The worn skin's `SkinOption.id`: "" for the wooden fish.
    var skin: String {
        didSet {
            defaults.set(skin, forKey: "skin")
            // Only the worn skin's folder is watched, so read the skins folder
            // afresh: another skin may have changed since the list was made.
            refreshSkins()
            loadSkin()
        }
    }
    private(set) var pack = SkinOption.woodenFish.pack
    /// The worn skin, small enough for the menu bar.
    private(set) var menuIcon = SkinOption.woodenFish.pack.idle.menuBarIcon()
    /// The skins in `skinsDirectory`.
    private(set) var skins: [SkinOption] = []
    /// Every skin to choose from: those that ship with the app, then the user's.
    var allSkins: [SkinOption] { SkinOption.builtIn + skins }

    static let skinsDirectory: URL = {
        let dir = URL.applicationSupportDirectory.appending(path: "Plinth/Skins")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    var placement: Placement {
        didSet { defaults.set(placement.rawValue, forKey: "placement"); onWindowChange?() }
    }
    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Plinth: launch at login failed: \(error)")
            }
        }
    }

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "interval": 1.0, "volume": 0.8, "size": FishSize.medium.rawValue,
            "placement": Placement.floating.rawValue,
        ])
        autoKnock = d.bool(forKey: "autoKnock")
        interval = d.double(forKey: "interval")
        stopAt108 = d.bool(forKey: "stopAt108")
        knockAsYouType = d.bool(forKey: "knockAsYouType")
        volume = d.double(forKey: "volume")
        size = FishSize(rawValue: d.string(forKey: "size") ?? "") ?? .medium
        placement = Placement(rawValue: d.string(forKey: "placement") ?? "") ?? .floating
        launchAtLogin = SMAppService.mainApp.status == .enabled
        skin = d.string(forKey: "skin") ?? ""
        refreshSkins()
        loadSkin()
        watchSkins()
        restartAuto()
        typing.onPress = { [weak self] in self?.knock(byHand: false, quick: true) }
        watchTyping()
    }

    /// Knock once. Auto-knock and typing pass `byHand: false`: only a knock on
    /// the fish itself is ever answered. `quick` is the short swing for typing.
    func knock(byHand: Bool = true, quick: Bool = false) {
        quickStrike = quick
        strikes += 1
        Task {
            try? await Task.sleep(for: .seconds(quick ? Self.quickImpactDelay : Self.impactDelay))
            let now = ProcessInfo.processInfo.systemUptime
            bloom = Self.bloom(afterSilence: now - lastImpact)
            lastImpact = now
            impacts += 1
            sound.play(volume: Float(volume), bloom: Float(bloom))
            if byHand { speak() }
        }
    }

    /// The longer the quiet before a knock, the more fully it rings: none of
    /// the hall after a rushed knock, all of it after twenty seconds of quiet.
    static func bloom(afterSilence seconds: Double) -> Double {
        let x = (log(seconds) - log(0.8)) / (log(20) - log(0.8))
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// The fish has a few things to say and says each of them once: the next
    /// line, on the first knock by hand each day. After the last, it only knocks.
    private func speak() {
        let said = defaults.integer(forKey: "said")
        let today = Self.today()
        guard said < Zen.sayings.count, defaults.string(forKey: "lastSaidDay") != today else { return }
        defaults.set(said + 1, forKey: "said")
        defaults.set(today, forKey: "lastSaidDay")
        let saying = Zen.sayings[said]
        // Long enough to read slowly.
        show(saying, for: min(14, max(7, Double(saying.text.count) * 0.4)))
    }

    private static func today() -> String {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }

    func refreshSkins() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: Self.skinsDirectory.path)) ?? []
        skins = files.sorted().compactMap { name in
            SkinPack.load(Self.skinsDirectory.appending(path: name)).map {
                SkinOption(id: name, title: $0.name ?? (name as NSString).deletingPathExtension, pack: $0)
            }
        }
    }

    /// Copy the images or skin folders the user picks into the skins folder
    /// and wear the first.
    func addSkins() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "Choose images, or skin folders that contain idle.png")
        guard panel.runModal() == .OK else { return }
        var added: [String] = []
        for url in panel.urls {
            let dest = Self.skinsDirectory.appending(path: url.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            if (try? FileManager.default.copyItem(at: url, to: dest)) != nil { added.append(dest.lastPathComponent) }
        }
        refreshSkins()
        if let first = added.first { skin = first }
    }

    /// Pick up skin images added, replaced or removed while the app runs.
    /// The folder sees files added, removed or swapped in; the worn skin's own
    /// file is watched too, since overwriting it in place leaves the folder as is.
    private func watchSkins() {
        skinWatcher = watch(Self.skinsDirectory, .write)
    }

    private func watch(_ url: URL, _ events: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: events, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.skinsChanged() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }

    private func skinsChanged() {
        // The folder changes as soon as a copy starts; wait for it to finish.
        skinRefresh?.cancel()
        skinRefresh = Task {
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            refreshSkins()
            if !allSkins.contains(where: { $0.id == skin }) { skin = "" } else { loadSkin() }
        }
    }

    private func loadSkin() {
        pack = (allSkins.first { $0.id == skin } ?? SkinOption.woodenFish).pack
        menuIcon = pack.idle.menuBarIcon()
        sound.use(voice: pack.voice)
        skinFileWatcher?.cancel()
        let isOwn = skins.contains { $0.id == skin }
        skinFileWatcher = isOwn ? watch(Self.skinsDirectory.appending(path: skin), [.write, .extend, .delete, .rename]) : nil
    }

    func show(_ quote: Quote, for seconds: Double = 8) {
        notice = quote
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            if notice == quote { notice = nil }
        }
    }

    private func watchTyping() {
        if knockAsYouType { typing.start() } else { typing.stop() }
    }

    private func restartAuto() {
        autoTask?.cancel()
        autoTask = nil
        guard autoKnock else { return }
        autoTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.interval ?? 1))
                guard let self, !Task.isCancelled else { return }
                knock(byHand: false)
                autoRound += 1
                // One turn of the mala, then quiet. The quiet says the rest.
                if stopAt108 && autoRound >= 108 { autoKnock = false }
            }
        }
    }
}

/// The worn skin's knock, synthesized, and its hall. A small pool of players
/// lets fast knocks overlap instead of cutting off.
///
/// The engine runs only while a knock rings. A running engine holds the audio
/// output open, which keeps the Mac from idle sleep and costs CPU even in silence.
@MainActor
final class KnockSound {
    private struct Slot {
        let dry: AVAudioPlayerNode
        let hall: AVAudioPlayerNode
        var freeAt = 0.0
    }

    /// How long the engine stays up after the last knock has rung out, so a
    /// run of knocks doesn't start it again for each one.
    private static let linger = 2.0

    private let engine = AVAudioEngine()
    private var slots: [Slot] = []
    private var cache: [KnockSynth.Variation] = []
    private var voice = ""
    private var quiet: Task<Void, Never>?
    private let mono = AVAudioFormat(standardFormatWithSampleRate: Double(KnockSynth.sampleRate), channels: 1)!
    private let stereo = AVAudioFormat(standardFormatWithSampleRate: Double(KnockSynth.sampleRate), channels: 2)!

    init() {
        for _ in 0..<12 {
            let dry = AVAudioPlayerNode()
            let hall = AVAudioPlayerNode()
            engine.attach(dry)
            engine.attach(hall)
            engine.connect(dry, to: engine.mainMixerNode, format: mono)
            engine.connect(hall, to: engine.mainMixerNode, format: stereo)
            slots.append(Slot(dry: dry, hall: hall))
        }
        engine.prepare()
    }

    /// Wear this voice. Unknown names, and none, are the wooden fish.
    func use(voice name: String?) {
        let next = KnockSynth.resolve(name)
        guard next != voice else { return }
        voice = next
        cache = KnockSynth.prepare(next)
    }

    /// Play one knock. `bloom` (0...1) is how much of the hall rings with it;
    /// a rushed knock is also a little quieter.
    func play(volume: Float, bloom: Float) {
        guard !cache.isEmpty, !slots.isEmpty else { return }
        // A player node raises an exception if played while its engine is down.
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        let now = ProcessInfo.processInfo.systemUptime
        let index = slots.indices.filter { slots[$0].freeAt <= now }.randomElement()
            ?? slots.indices.min { slots[$0].freeAt < slots[$1].freeAt }!
        let variation = cache.randomElement()!
        // No two knocks are quite the same.
        let rate = Float.random(in: 0.98...1.02)
        let gain = volume * .random(in: 0.88...1.0)
        let ringsHall = bloom > 0.01
        guard let dry = buffer(variation.dry, format: mono, rate: rate) else { return }
        start(slots[index].dry, dry, volume: gain * (0.8 + 0.2 * bloom))
        var until = now + Double(dry.frameLength) / Double(KnockSynth.sampleRate)
        if ringsHall, let hall = buffer(variation.left, variation.right, format: stereo, rate: rate) {
            start(slots[index].hall, hall, volume: gain * bloom)
            until = max(until, now + Double(hall.frameLength) / Double(KnockSynth.sampleRate))
        } else {
            slots[index].hall.stop()
        }
        slots[index].freeAt = until
        pauseWhenQuiet()
    }

    /// Pause the engine once every knock has rung out, plus `linger`.
    private func pauseWhenQuiet() {
        quiet?.cancel()
        let ringsUntil = slots.map(\.freeAt).max() ?? 0
        let wait = ringsUntil + Self.linger - ProcessInfo.processInfo.systemUptime
        quiet = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(wait, 0)))
            guard !Task.isCancelled, let self else { return }
            self.engine.pause()
        }
    }

    private func start(_ node: AVAudioPlayerNode, _ buffer: AVAudioPCMBuffer, volume: Float) {
        node.stop()
        node.volume = volume
        node.scheduleBuffer(buffer, completionHandler: nil)
        node.play()
    }

    private func buffer(_ samples: [Float], format: AVAudioFormat, rate: Float) -> AVAudioPCMBuffer? {
        guard samples.count > 1,
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Float(samples.count) / rate) + 1),
              let dst = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = AVAudioFrameCount(write(samples, into: dst, capacity: Int(buf.frameCapacity), rate: rate))
        return buf
    }

    private func buffer(_ left: [Float], _ right: [Float], format: AVAudioFormat, rate: Float) -> AVAudioPCMBuffer? {
        guard left.count > 1,
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Float(left.count) / rate) + 1),
              let l = buf.floatChannelData?[0], let r = buf.floatChannelData?[1] else { return nil }
        let n = write(left, into: l, capacity: Int(buf.frameCapacity), rate: rate)
        _ = write(right, into: r, capacity: Int(buf.frameCapacity), rate: rate)
        buf.frameLength = AVAudioFrameCount(n)
        return buf
    }

    private func write(_ samples: [Float], into dst: UnsafeMutablePointer<Float>, capacity: Int, rate: Float) -> Int {
        var n = 0
        var pos: Float = 0
        let last = samples.count - 1
        while n < capacity && pos < Float(last) {
            let j = Int(pos)
            let f = pos - Float(j)
            dst[n] = samples[j] + (samples[j + 1] - samples[j]) * f
            pos += rate
            n += 1
        }
        return n
    }
}
