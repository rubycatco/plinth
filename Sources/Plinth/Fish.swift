import AppKit
import Observation
import PlinthCore
import ServiceManagement
import UniformTypeIdentifiers

enum Placement: String, CaseIterable, Identifiable {
    /// `unseen`: no fish on screen, only its knock and the menu bar icon.
    case floating, desktop, unseen
    var id: Self { self }
    var title: String {
        switch self {
        case .floating: String(localized: "Above windows")
        case .desktop: String(localized: "On the desktop")
        case .unseen: String(localized: "Heard, not seen")
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

/// Hurried keys gradually soften the hand; a pause lets it open again.
/// Only gaps are used, never the keys themselves, and nothing is stored.
struct TypingCadence {
    private var settling = 0.0

    mutating func press(after seconds: Double) -> Float {
        let gap = max(seconds, 0)
        let hurry = min(max((0.4 - gap) / 0.32, 0), 1)
        if hurry > settling {
            settling += (hurry - settling) * 0.22
        } else {
            settling = hurry + (settling - hurry) * exp(-gap / 0.8)
        }
        return Float(settling)
    }
}

@MainActor @Observable
final class Fish {
    static let shared = Fish()

    /// 开静: first gently, then evenly, then firmly. Leave half a beat more
    /// before the last knock, and time after it for the held mallet to rise.
    static let callStrokes: [(gap: Double, force: Float)] = [(1.6, 0.38), (1.6, 0.56), (2.4, 0.78)]
    static let callRest = 2.0
    /// How long a call lasts when no one answers it.
    static let callLength = callStrokes.reduce(0) { $0 + $1.gap } + callRest
    /// The bell: after this long at the keyboard with no rest of `rest`, typed
    /// knocks and auto-knock fall quiet, and after `bellQuiet` one knock rings
    /// in full, set apart from them as a hall's signal is; they keep quiet
    /// `breaths` more, about three breaths.
    static let bellAfter = 30.0 * 60
    static let rest = 3.0 * 60
    static let bellQuiet = 3.0
    static let breaths = 15.0
    /// Auto-knock goes on this long after the screens sleep, as through a
    /// sitting with closed eyes, then rests, so the Mac can sleep too.
    static let darkFor = 60.0 * 60

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let sound = KnockSound(headphones: Headphones.inUse)
    @ObservationIgnored private let typing = TypingWatcher()
    @ObservationIgnored private let malletWatcher = MalletKeyWatcher()
    @ObservationIgnored private var autoTask: Task<Void, Never>?
    @ObservationIgnored private var autoSwing: Task<Void, Never>?
    @ObservationIgnored var onWindowChange: (() -> Void)?
    @ObservationIgnored private var skinWatcher: DispatchSourceFileSystemObject?
    @ObservationIgnored private var skinFileWatcher: DispatchSourceFileSystemObject?
    @ObservationIgnored private var skinRefresh: Task<Void, Never>?
    /// The files each of `skins` was read from, as they were then.
    @ObservationIgnored private var skinStamps: [String: [FileStamp]] = [:]
    /// When the mallet last met the wood, on the system uptime clock.
    @ObservationIgnored private var lastImpact = -Double.infinity

    /// The mallet's latest swing; each new one swings it again.
    private(set) var swing = Swing()
    /// A swing by hand still in the air, until the mallet lands.
    @ObservationIgnored private var handSwing: (serial: Int, task: Task<Void, Never>)?
    /// A typed key's short swing still in the air, cancelled if a knock by hand
    /// (such as the mallet key) arrives in the same keystroke.
    @ObservationIgnored private var quickSwing: Task<Void, Never>?
    @ObservationIgnored private var recordingMalletKey = false
    /// A knock to sound once the room being rendered is ready, to hear it.
    @ObservationIgnored private var previewAfterSpace = false
    /// Counts the moments the mallet meets the figure. Nothing else is
    /// counted: knocking earns no merit.
    private(set) var impacts = 0
    /// How fully the last knock rang: 0 after a rushed knock, 1 after a long quiet.
    private(set) var bloom = 1.0
    private(set) var notice: Notice?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    /// Auto-knocks since it was turned on, for Stop after 108.
    private var autoRound = 0
    /// Auto-knocks since the rhythm last changed, so a new rhythm starts at its beginning.
    private var rhythmStep = 0
    /// The stick of incense burning beside the fish, if one is lit.
    private(set) var incense: Incense?
    @ObservationIgnored private var incenseTask: Task<Void, Never>?
    /// The fish calling you back, while it sounds, and when its first knock
    /// landed, from which a key or click anywhere ends the call. See `call()`.
    @ObservationIgnored private var callTask: Task<Void, Never>?
    @ObservationIgnored private var callSwing: Task<Void, Never>?
    @ObservationIgnored private var callLanded = Double.infinity
    /// When the last key went down, and when the stretch of typing it belongs
    /// to began, on a clock that keeps going while the Mac sleeps, since a
    /// night's sleep is a rest. Kept only for the bell, never stored.
    @ObservationIgnored private var lastTyped = -Double.infinity
    @ObservationIgnored private var typingSince = 0.0
    @ObservationIgnored private var typingCadence = TypingCadence()
    /// Until when typed knocks keep quiet, after the bell or lighting incense.
    @ObservationIgnored private var hushUntil = 0.0
    /// The bell's quiet, its knock, and the breaths after it. Auto-knock waits.
    @ObservationIgnored private var bellTask: Task<Void, Never>?
    @ObservationIgnored private var bellSwing: Task<Void, Never>?
    /// The screens have slept for `darkFor`, and auto-knock rests until they
    /// wake. `restSoon` waits for that, while they sleep.
    @ObservationIgnored private var resting = false
    @ObservationIgnored private var restSoon: Task<Void, Never>?

    var autoKnock: Bool {
        didSet { defaults.set(autoKnock, forKey: "autoKnock"); autoRound = 0; rhythmStep = 0; restartAuto() }
    }
    var interval: Double {
        didSet { defaults.set(interval, forKey: "interval"); restartAuto() }
    }
    var rhythm: Rhythm {
        didSet { defaults.set(rhythm.rawValue, forKey: "rhythm"); rhythmStep = 0; restartAuto() }
    }
    var stopAt108: Bool { didSet { defaults.set(stopAt108, forKey: "stopAt108") } }
    /// Each key pressed in any app knocks once. Typed knocks are never answered.
    var knockAsYouType: Bool {
        didSet {
            defaults.set(knockAsYouType, forKey: "knockAsYouType")
            typingCadence = TypingCadence()
            watchTyping()
        }
    }
    /// After a long stretch of typing, one knock to stop and breathe: the fish
    /// that never sleeps, keeping you from dozing off at the keyboard.
    var bell: Bool {
        didSet { defaults.set(bell, forKey: "bell"); watchTyping() }
    }
    var volume: Double { didSet { defaults.set(volume, forKey: "volume") } }
    /// The room the knock rings in: 0 a small meditation room, 1 a great hall.
    var space: Double {
        didSet {
            defaults.set(space, forKey: "space")
            // Rendering the room takes a moment, so wait for the slider to settle.
            spaceChange?.cancel()
            spaceChange = Task {
                try? await Task.sleep(for: .seconds(0.25))
                guard !Task.isCancelled else { return }
                sound.use(voice: pack.voice, space: Float(space))
                spaceChange = nil
                if previewAfterSpace {
                    previewAfterSpace = false
                    preview()
                }
            }
        }
    }
    @ObservationIgnored private var spaceChange: Task<Void, Never>?
    /// While another app listens to a microphone, as in a meeting, only a
    /// knock by hand sounds; the others swing in silence.
    var quietWhileMicInUse: Bool {
        didSet { defaults.set(quietWhileMicInUse, forKey: "quietWhileMicInUse") }
    }
    var size: FishSize {
        didSet { defaults.set(size.rawValue, forKey: "size"); onWindowChange?() }
    }
    /// A key, pedal or button that is the mallet: pressed in any app, it
    /// knocks as a click on the fish does. See `useMalletKey`.
    private(set) var malletKey: MalletKey?
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
    private(set) var pack = SkinOption.inkFish.pack
    /// The worn skin, small enough for the menu bar.
    private(set) var menuIcon = SkinOption.inkFish.pack.idle.menuBarIcon()
    /// The skins in `skinsDirectory`.
    private(set) var skins: [SkinOption] = []
    /// Every skin to choose from: those that ship with the app, then the user's.
    var allSkins: [SkinOption] { SkinOption.builtIn + skins }

    /// The community gallery, where skins are shared as .plinthskin files.
    static let moreSkins = URL(string: "https://github.com/rubycatco/plinth-skins")!
    /// The skin format, in the language the app is showing.
    static let skinGuide = URL(string: Bundle.main.preferredLocalizations.first == "zh-Hans"
        ? "https://github.com/rubycatco/plinth/blob/main/docs/SKINS.zh-Hans.md"
        : "https://github.com/rubycatco/plinth/blob/main/docs/SKINS.md")!

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
            "interval": 1.0, "volume": 0.8, "space": Double(KnockSynth.Hall.defaultSpace), "size": FishSize.medium.rawValue,
            "placement": Placement.floating.rawValue, "quietWhileMicInUse": true,
        ])
        autoKnock = d.bool(forKey: "autoKnock")
        interval = d.double(forKey: "interval")
        rhythm = Rhythm(rawValue: d.string(forKey: "rhythm") ?? "") ?? .steady
        stopAt108 = d.bool(forKey: "stopAt108")
        knockAsYouType = d.bool(forKey: "knockAsYouType")
        bell = d.bool(forKey: "bell")
        volume = d.double(forKey: "volume")
        space = d.double(forKey: "space")
        quietWhileMicInUse = d.bool(forKey: "quietWhileMicInUse")
        size = FishSize(rawValue: d.string(forKey: "size") ?? "") ?? .medium
        placement = Placement(rawValue: d.string(forKey: "placement") ?? "") ?? .floating
        launchAtLogin = SMAppService.mainApp.status == .enabled
        // A skin is stored only once one is chosen; until then, the ink fish.
        skin = d.string(forKey: "skin") ?? SkinOption.inkFish.id
        refreshSkins()
        loadSkin()
        watchSkins()
        restartAuto()
        typing.onPress = { [weak self] in self?.typed() }
        watchTyping()
        malletKey = MalletKey(stored: d.dictionary(forKey: "malletKey"))
        malletWatcher.onPress = { [weak self] in
            self?.typing.skip()
            self?.knock(byHand: true)
        }
        _ = malletWatcher.watch(malletKey)
        // A while after the screens sleep, auto-knock rests, and the Mac can sleep.
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensSlept() }
        }
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensWoke() }
        }
        pressMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .pressure]) { [weak self] event in
            self?.feel(event)
            return event
        }
    }

    /// Knock once. Auto-knock and typing pass `byHand: false`: only a knock on
    /// the fish itself is ever answered. `quick` is the short swing for typing.
    /// `at` is where a click landed across the fish, from 0 at its left edge
    /// to 1 at its right. A `preview`, to hear a setting, always sounds and is
    /// never answered. A `full` knock rings as fully as after a long quiet,
    /// however lately the fish was knocked. `closing` rests the mallet on the
    /// wood at a ritual's close; `settling` softens hurried typing.
    func knock(byHand: Bool = true, quick: Bool = false, at x: Double? = nil, preview: Bool = false,
               full: Bool = false, closing: Bool = false, settling: Float = 0) {
        // While the fish calls you back, other knocks keep quiet, so the call
        // is heard. A knock by hand, or a setting changed, means you are here,
        // and the call has done its work.
        if callTask != nil {
            if byHand || preview { endCall() } else { return }
        }
        strike(byHand: byHand, quick: quick, at: x, preview: preview, full: full, closing: closing, settling: settling)
    }

    @discardableResult
    private func strike(byHand: Bool, quick: Bool = false, at x: Double? = nil, preview: Bool = false,
                        full: Bool = false, closing: Bool = false, settling: Float = 0,
                        force: Float? = nil, automatic: Bool = false) -> Task<Void, Never> {
        if byHand {
            quickSwing?.cancel()
            quickSwing = nil
        }
        let delay = quick ? Swing.quickImpactDelay : Swing.impactDelay
        let silence = ProcessInfo.processInfo.systemUptime + delay - lastImpact
        let lingers = !quick && !preview && (closing || (byHand && (full || KnockSound.bloom(afterSilence: silence) > 0.9)))
        swing = Swing(serial: swing.serial + 1, quick: quick, lingers: lingers)
        let serial = swing.serial
        let audible = volume > 0 && (byHand || preview || !quietWhileMicInUse || !Microphone.inUseByOthers())
        // Wake the audio while the mallet is in the air, so the first knock
        // after a quiet lands with the mallet rather than a moment after it.
        if audible { sound.warm(for: delay) }
        // A press is read a moment into the swing, once a Force Touch trackpad
        // has felt how firm it is. A typed key has no time to spare.
        let feel = quick ? 0 : Swing.liftDuration
        let swingTask = Task {
            try? await Task.sleep(for: .seconds(feel))
            guard !Task.isCancelled else { return }
            let deep = (press?.stage ?? 0) >= 2
            let (touchForce, place) = touch(byHand: byHand, quick: quick, at: x,
                                       silence: full ? .infinity : ProcessInfo.processInfo.systemUptime + delay - feel - lastImpact)
            // The knock is made while the mallet is in the air.
            let knock = sound.synthesize(force: force ?? touchForce, place: place, settling: quick ? settling : 0)
            try? await Task.sleep(for: .seconds(delay - feel))
            guard !Task.isCancelled else { return }
            if handSwing?.serial == serial { handSwing = nil }
            let samples = await knock.value
            guard !Task.isCancelled else { return }
            if quick && swing.serial == serial { quickSwing = nil }
            let now = ProcessInfo.processInfo.systemUptime
            bloom = full ? 1 : KnockSound.bloom(afterSilence: now - lastImpact)
            lastImpact = now
            impacts += 1
            if audible {
                sound.play(samples, volume: Float(volume), bloom: Float(bloom), unseen: placement == .unseen)
            }
            if byHand && !preview {
                // A Force Touch trackpad taps back as the mallet lands, harder
                // for a deep press. macOS plays it only while a finger rests
                // on the trackpad, as it still does when the knock is pressed.
                NSHapticFeedbackManager.defaultPerformer.perform(deep ? .levelChange : .generic,
                                                                 performanceTime: .now)
                speak()
            }
            if automatic {
                autoSwing = nil
                // Count landings, not swings: a ritual may hush one in the air.
                autoRound += 1
                rhythmStep += 1
                if stopAt108 && autoRound >= 108 { autoKnock = false }
            }
        }
        if byHand && !preview { handSwing = (serial, swingTask) }
        else if quick { quickSwing = swingTask }
        return swingTask
    }

    /// Make `key` the mallet, or have none. False, and nothing changes, if
    /// another app already holds the key.
    func useMalletKey(_ key: MalletKey?) -> Bool {
        guard malletWatcher.watch(key) else {
            // Put the old key back, unless a new one is being recorded.
            _ = malletWatcher.watch(recordingMalletKey ? nil : malletKey)
            return false
        }
        malletKey = key
        if let key { defaults.set(key.stored, forKey: "malletKey") } else { defaults.removeObject(forKey: "malletKey") }
        return true
    }

    /// While a new mallet key is being recorded, the old one lets go of its
    /// key, so pressing it again records it rather than knocking.
    func holdMalletKey(_ hold: Bool) {
        recordingMalletKey = !hold
        typing.skip()
        _ = malletWatcher.watch(hold ? malletKey : nil)
    }

    /// The fish is being moved, not knocked: a swing by hand still in the air
    /// goes back up without landing.
    func callOff() {
        guard let handSwing else { return }
        handSwing.task.cancel()
        self.handSwing = nil
        swing = Swing(serial: swing.serial + 1, calledOff: true)
    }

    /// One knock to hear a setting just changed: the volume, the room, or a skin.
    func preview() {
        if spaceChange != nil {
            previewAfterSpace = true
        } else {
            knock(byHand: false, preview: true)
        }
    }

    /// Knock the ink fish painted on the About scroll: always the ink voice,
    /// heard through paper, whatever the fish on the desktop wears, and that
    /// fish's mallet stays still. Like a preview, it always sounds, and a call
    /// ends: you are here.
    func knockPainting() {
        endCall()
        guard volume > 0 else { return }
        sound.warm(for: 0)
        let knock = sound.synthesize(force: 0.58 + .random(in: -0.07...0.07), place: .random(in: -0.2...0.2), voice: "ink")
        Task {
            let samples = await knock.value
            // It rings in the same hall as the desktop fish.
            let now = ProcessInfo.processInfo.systemUptime
            let bloom = KnockSound.bloom(afterSilence: now - lastImpact)
            lastImpact = now
            sound.play(samples, volume: Float(volume), bloom: Float(bloom), unseen: placement == .unseen)
        }
    }

    /// How hard and where a knock lands. A firm click lands harder and a deep
    /// one hardest; a hand in a hurry lands lighter, and a typed key lighter
    /// still. A click off the strike point lands toward the edge.
    private func touch(byHand: Bool, quick: Bool, at x: Double?, silence: Double) -> (force: Float, place: Float) {
        let rested = Float(KnockSound.bloom(afterSilence: silence))
        var force: Float
        if quick {
            force = 0.36 + 0.2 * rested + .random(in: -0.05...0.05)
        } else if byHand, let press {
            force = press.stage >= 2 ? 0.95 : 0.4 + 0.4 * press.pressure
            force *= 0.85 + 0.15 * rested
        } else {
            force = Swing.force(rested: rested)
        }
        press = nil
        return (min(max(force, 0.1), 1), Swing.place(at: x, strike: pack.strike.x))
    }

    /// How firmly the latest click on the fish went down, from a Force Touch
    /// trackpad: the stage-one pressure, 0 to 1, and stage 2 for a deep click.
    /// Nil from a mouse.
    @ObservationIgnored private var press: (pressure: Float, stage: Int)?
    @ObservationIgnored private var pressMonitor: Any?

    private func feel(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            press = nil
        } else {
            var p = press ?? (0, 0)
            if event.stage == 1 { p.pressure = max(p.pressure, event.pressure) }
            p.stage = max(p.stage, event.stage)
            press = p
        }
    }

    /// Place the knock where the fish sits, from the middle of the main
    /// display: `across` in its widths to the right, `up` in its heights.
    func heard(across: Double, up: Double) {
        // With no figure to locate, leave screen position behind. The dry
        // centre is softened in play(), with more of the surrounding hall.
        sound.place(across: placement == .unseen ? 0 : Float(across),
                    up: placement == .unseen ? 0 : Float(up))
    }

    /// The fish has a few things to say and says each of them once: the next
    /// line, on the first knock by hand each day (from 4 a.m.). After the last, it only knocks.
    private func speak() {
        let said = defaults.integer(forKey: "said")
        // An unseen fish has no words either; they wait until it is seen.
        guard placement != .unseen, said < Zen.sayings.count else { return }
        let today = Self.today()
        guard defaults.string(forKey: "lastSaidDay") != today else { return }
        defaults.set(said + 1, forKey: "said")
        defaults.set(today, forKey: "lastSaidDay")
        let saying = Zen.sayings[said]
        // Long enough to read slowly.
        show(saying, for: min(14, max(7, Double(saying.text.count) * 0.4)))
    }

    /// A temple's day begins when the board is struck to wake the hall, before
    /// dawn, not at midnight: a knock at one in the morning is still last night.
    private static func today() -> String {
        let dawn = Calendar.current.date(byAdding: .hour, value: -4, to: .now) ?? .now
        let day = Calendar.current.dateComponents([.year, .month, .day], from: dawn)
        return "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }

    /// Read the skins folder. A skin whose files are as they were is kept, not
    /// decoded again, so choosing a skin costs only a look at the folder.
    func refreshSkins() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: Self.skinsDirectory.path)) ?? []
        let known = Dictionary(skins.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var stamps: [String: [FileStamp]] = [:]
        skins = files.sorted().compactMap { name in
            let url = Self.skinsDirectory.appending(path: name)
            let stamp = FileStamp.of(url)
            stamps[name] = stamp
            if let kept = known[name], skinStamps[name] == stamp { return kept }
            return SkinPack.load(url).map {
                SkinOption(id: name, title: $0.name ?? (name as NSString).deletingPathExtension, pack: $0)
            }
        }
        skinStamps = stamps
    }

    /// Add the images, skin folders or `.plinthskin` files the user picks.
    func addSkins() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, SkinArchive.type]
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "Choose images, skin folders that contain idle.png, or .plinthskin files")
        guard panel.runModal() == .OK else { return }
        install(panel.urls)
    }

    /// Copy images, skin folders and `.plinthskin` files into the skins folder,
    /// replacing any of the same name, and wear the first.
    func install(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        var added: [String] = []
        var refused: [String] = []
        for url in urls {
            var source = url
            var name = url.lastPathComponent
            let scratch = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: scratch) }
            if url.pathExtension.lowercased() == "plinthskin" {
                guard let folder = try? SkinArchive.unpack(url, into: scratch) else {
                    refused.append(url.lastPathComponent)
                    continue
                }
                source = folder
                // The folder inside keeps its name when a download is renamed "skin (1)".
                name = folder == scratch ? url.deletingPathExtension().lastPathComponent : folder.lastPathComponent
            }
            let dest = Self.skinsDirectory.appending(path: name)
            try? FileManager.default.removeItem(at: dest)
            if (try? FileManager.default.copyItem(at: source, to: dest)) != nil, SkinPack.load(dest) != nil {
                added.append(name)
            } else {
                try? FileManager.default.removeItem(at: dest)
                refused.append(url.lastPathComponent)
            }
        }
        refreshSkins()
        if let first = added.first { skin = first }
        if !refused.isEmpty {
            let alert = NSAlert()
            alert.messageText = String(localized: "Some skins couldn't be added")
            alert.informativeText = refused.joined(separator: "\n") + "\n\n"
                + String(localized: "A skin is an image, or a folder with idle.png. A .plinthskin file is such a folder, zipped.")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    /// Save a skin of your own as a `.plinthskin` file, to share.
    func export(_ option: SkinOption) {
        let folder = Self.skinsDirectory.appending(path: option.id)
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [SkinArchive.type]
        panel.nameFieldStringValue = "\(option.id).plinthskin"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !SkinArchive.pack(folder, to: url) { NSSound.beep() }
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
            if !allSkins.contains(where: { $0.id == skin }) { skin = SkinOption.inkFish.id } else { loadSkin() }
        }
    }

    private func loadSkin() {
        pack = (allSkins.first { $0.id == skin } ?? SkinOption.inkFish).pack
        menuIcon = pack.idle.menuBarIcon()
        sound.use(voice: pack.voice, space: Float(space))
        skinFileWatcher?.cancel()
        let isOwn = skins.contains { $0.id == skin }
        skinFileWatcher = isOwn ? watch(Self.skinsDirectory.appending(path: skin), [.write, .extend, .delete, .rename]) : nil
    }

    func show(_ quote: Quote, for seconds: Double = 8) {
        noticeTask?.cancel()
        notice = Notice(quote: quote)
        noticeTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            if quote.leavesSilence {
                notice?.silent = true
                // The text takes 0.4 seconds to fade, then two empty seconds.
                try? await Task.sleep(for: .seconds(2.4))
                guard !Task.isCancelled else { return }
            }
            notice = nil
            noticeTask = nil
        }
    }

    /// Light a stick of incense: one knock as it is lit, quiet while it burns,
    /// three knocks as it goes out. The first is 止静, the start of a sitting,
    /// and rings fully even just after a knock. Nothing is counted or kept.
    func lightIncense(_ length: IncenseLength) {
        incenseTask?.cancel()
        bellTask?.cancel()
        bellTask = nil
        bellSwing?.cancel()
        bellSwing = nil
        pauseAccompaniment()
        // Draw once per stick: the ember and the closing call share its life.
        let stick = Incense(lit: .now, duration: Double(length.rawValue) * 60 * .random(in: 0.98...1.02))
        incense = stick
        let now = Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1e9
        hushUntil = max(hushUntil, now + Swing.impactDelay + Self.breaths)
        endCall()
        knock(byHand: false, full: true, closing: true)
        incenseTask = Task { [weak self] in
            // The continuous clock keeps burning while the Mac sleeps.
            try? await Task.sleep(for: .seconds(stick.duration))
            guard let self, !Task.isCancelled else { return }
            // The spent stick stays while the ember dies and its last smoke
            // drifts away under the call: as long as a call lasts, even one
            // answered at its first knock. A new stick lit meanwhile ends
            // this one's.
            let out = ContinuousClock.now
            call()
            await callTask?.value
            try? await Task.sleep(until: out + .seconds(Self.callLength), clock: .continuous)
            guard !Task.isCancelled else { return }
            incense = nil
            incenseTask = nil
            restartAuto()
        }
    }

    /// Put the incense out early, without a knock.
    func putOutIncense() {
        incenseTask?.cancel()
        incenseTask = nil
        incense = nil
        endCall()
        restartAuto()
    }

    /// Call you back, as a stick of incense does when it goes out: three
    /// knocks. So they are heard over auto-knock or typing, those keep quiet
    /// for the call, and the three come after a quiet, each ringing in full
    /// through the hall. Auto-knock picks up again after. A call that comes
    /// while one sounds is the same call. Like auto-knock, it is never answered.
    /// Once the first knock has sounded, a key or a click anywhere means you
    /// are back, and the rest of the call keeps quiet. One from before it,
    /// such as the key that started a build, doesn't count.
    func call() {
        guard callTask == nil else { return }
        pauseAccompaniment()
        callLanded = .infinity
        callTask = Task { [weak self] in
            for (index, stroke) in Self.callStrokes.enumerated() {
                try? await Task.sleep(for: .seconds(stroke.gap))
                guard let self, !Task.isCancelled else { return }
                let answered = max(TypingWatcher.lastEvent(.keyDown), TypingWatcher.lastEvent(.leftMouseDown))
                if answered > callLanded { return endCall() }
                callSwing = strike(byHand: false, full: true, closing: index == 2, force: stroke.force)
                if callLanded == .infinity {
                    callLanded = ProcessInfo.processInfo.systemUptime + Swing.impactDelay
                }
            }
            try? await Task.sleep(for: .seconds(Self.callRest))
            guard let self, !Task.isCancelled else { return }
            endCall()
        }
    }

    /// End a call before its last knock: you are here.
    private func endCall() {
        guard let callTask else { return }
        callTask.cancel()
        self.callTask = nil
        callSwing?.cancel()
        callSwing = nil
        callLanded = .infinity
        restartAuto()
    }

    private func watchTyping() {
        if knockAsYouType || bell { typing.start(keyByKey: knockAsYouType) } else { typing.stop() }
    }

    /// A key went down, in some app. It knocks, if knocking as you type; and
    /// once you have typed long enough without a rest, the bell knocks instead.
    private func typed() {
        guard !recordingMalletKey else { return }
        // A key that went down after the call's first knock means you are
        // back. When it went down, not when the watcher noticed: for the bell
        // alone it looks only about once a second, and a key from before the
        // knock may be noticed after it.
        if callTask != nil, TypingWatcher.lastEvent(.keyDown) > callLanded {
            endCall()
        }
        let now = Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1e9
        let settling = knockAsYouType ? typingCadence.press(after: now - lastTyped) : 0
        if now - lastTyped > Self.rest { typingSince = now }
        lastTyped = now
        // A call already has your ear; the bell waits for the next key after it.
        if bell && callTask == nil && bellTask == nil && now >= hushUntil && now - typingSince >= Self.bellAfter {
            typingSince = now
            hushUntil = now + Self.bellQuiet + Swing.impactDelay + Self.breaths
            pauseAccompaniment()
            // A quiet first, so the bell isn't lost among other knocks, and
            // then it rings in full, as the hall's signal it is.
            bellTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.bellQuiet))
                guard let self, !Task.isCancelled else { return }
                if bell && callTask == nil { bellSwing = strike(byHand: false, full: true, closing: true) }
                try? await Task.sleep(for: .seconds(Swing.impactDelay + Self.breaths))
                guard !Task.isCancelled else { return }
                bellTask = nil
                bellSwing = nil
                restartAuto()
            }
        } else if knockAsYouType && now >= hushUntil {
            knock(byHand: false, quick: true, settling: settling)
        }
    }

    /// With eyes closed, the screens may sleep while you sit: auto-knock goes
    /// on for `darkFor`. Left knocking past that, it rests.
    private func screensSlept() {
        restSoon?.cancel()
        restSoon = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.darkFor))
            guard let self, !Task.isCancelled else { return }
            restSoon = nil
            resting = true
            restartAuto()
        }
    }

    /// The screens are awake: auto-knock starts again if it was resting, and
    /// otherwise keeps its beat.
    private func screensWoke() {
        restSoon?.cancel()
        restSoon = nil
        guard resting else { return }
        resting = false
        restartAuto()
    }

    /// A hall's signal hushes even an accompaniment swing still in the air.
    /// Keep the setting and the round, so it can resume where it left off.
    private func pauseAccompaniment() {
        autoTask?.cancel()
        autoTask = nil
        autoSwing?.cancel()
        autoSwing = nil
        quickSwing?.cancel()
        quickSwing = nil
    }

    private func restartAuto() {
        autoTask?.cancel()
        autoTask = nil
        guard autoKnock, incense == nil, callTask == nil, bellTask == nil, !resting else { return }
        autoTask = Task { [weak self] in
            var lastSwing = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                guard let next = self.map({ fish in
                    var gap = fish.rhythm.gap(before: fish.rhythmStep, interval: fish.interval)
                    // 煞板: the last three knocks of a mala's turn slow down, each
                    // gap wider than the last, and the last rings fully into the quiet.
                    let left = fish.stopAt108 ? 108 - fish.autoRound : 0
                    if (1...3).contains(left) { gap = max(gap, fish.interval) * pow(1.5, Double(4 - left)) }
                    return gap
                }) else { return }
                // The gap is between swings, not between the previous landing
                // and the next swing. Awaiting the landing must not slow the beat.
                let wait = max(0, next - (ProcessInfo.processInfo.systemUptime - lastSwing))
                try? await Task.sleep(for: .seconds(wait))
                guard let self, !Task.isCancelled else { return }
                // Read the option again after sleeping: it may have changed.
                let last = stopAt108 && autoRound == 107
                let stroke = rhythm.stroke(at: rhythmStep)
                lastSwing = ProcessInfo.processInfo.systemUptime
                let pending = strike(byHand: false, full: last || stroke.closing, closing: last || stroke.closing,
                                     force: stroke.force, automatic: true)
                autoSwing = pending
                await pending.value
            }
        }
    }
}
