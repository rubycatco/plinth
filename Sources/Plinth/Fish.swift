import AppKit
import AVFoundation
import Observation
import os
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

/// How auto-knock spaces its knocks around the chosen interval.
enum Rhythm: String, CaseIterable, Identifiable {
    case steady, quickening, natural
    var id: Self { self }
    var title: String {
        switch self {
        case .steady: String(localized: "Steady")
        case .quickening: String(localized: "Quickening")
        case .natural: String(localized: "Natural")
        }
    }

    /// One line on what this rhythm sounds like, for Settings.
    var about: String {
        switch self {
        case .steady: String(localized: "Steady: the same quiet between every knock.")
        case .quickening: String(localized: "Quickening (起板): slow, then faster into a roll, as a chant begins; then a rest.")
        case .natural: String(localized: "Natural: each gap runs a little long or short, like a hand keeping time.")
        }
    }

    /// The quiet before auto-knock's knock number `n`, counting from 0.
    func gap(before n: Int, interval: Double) -> Double {
        switch self {
        case .steady:
            return interval
        case .natural:
            // A hand keeping time: each gap a little long or short, about 0.7 to 1.4 times.
            return interval * exp(.random(in: -0.35...0.35))
        case .quickening:
            // 起板: a round of fifteen knocks that starts slow and quickens
            // into a roll, then a rest before the next round begins.
            let k = n % 15
            if k == 0 { return n == 0 ? interval : interval * 5 }
            return max(interval * 2.5 * pow(0.1, Double(k - 1) / 13), 0.15)
        }
    }
}

/// One swing of the mallet. `quick` is the short swing for a typed key;
/// `calledOff` takes a swing still in the air back up without landing.
struct Swing: Equatable {
    var serial = 0
    var quick = false
    var calledOff = false
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
    /// A call's three knocks come this far apart, after as long a quiet, and
    /// the call lasts as long as `callLength`. See `call()`.
    static let callBeat = 1.6
    static let callLength = callBeat * 3 + 2
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
    @ObservationIgnored private let sound = KnockSound()
    @ObservationIgnored private let typing = TypingWatcher()
    @ObservationIgnored private var autoTask: Task<Void, Never>?
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
    /// A knock to sound once the room being rendered is ready, to hear it.
    @ObservationIgnored private var previewAfterSpace = false
    /// Counts the moments the mallet meets the figure. Nothing else is
    /// counted: knocking earns no merit.
    private(set) var impacts = 0
    /// How fully the last knock rang: 0 after a rushed knock, 1 after a long quiet.
    private(set) var bloom = 1.0
    private(set) var notice: Quote?
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
    @ObservationIgnored private var callLanded = Double.infinity
    /// When the last key went down, and when the stretch of typing it belongs
    /// to began, on a clock that keeps going while the Mac sleeps, since a
    /// night's sleep is a rest. Kept only for the bell, never stored.
    @ObservationIgnored private var lastTyped = -Double.infinity
    @ObservationIgnored private var typingSince = 0.0
    /// Until when typed knocks keep quiet, after the bell.
    @ObservationIgnored private var hushUntil = 0.0
    /// The bell's quiet, its knock, and the breaths after it. Auto-knock waits.
    @ObservationIgnored private var bellTask: Task<Void, Never>?
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
        didSet { defaults.set(knockAsYouType, forKey: "knockAsYouType"); watchTyping() }
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
        skin = d.string(forKey: "skin") ?? ""
        refreshSkins()
        loadSkin()
        watchSkins()
        restartAuto()
        typing.onPress = { [weak self] in self?.typed() }
        watchTyping()
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
    /// however lately the fish was knocked.
    func knock(byHand: Bool = true, quick: Bool = false, at x: Double? = nil, preview: Bool = false, full: Bool = false) {
        // While the fish calls you back, other knocks keep quiet, so the call
        // is heard. A knock by hand, or a setting changed, means you are here,
        // and the call has done its work.
        if callTask != nil {
            if byHand || preview { endCall() } else { return }
        }
        strike(byHand: byHand, quick: quick, at: x, preview: preview, full: full)
    }

    private func strike(byHand: Bool, quick: Bool = false, at x: Double? = nil, preview: Bool = false, full: Bool = false) {
        swing = Swing(serial: swing.serial + 1, quick: quick)
        let serial = swing.serial
        let delay = quick ? Self.quickImpactDelay : Self.impactDelay
        let audible = volume > 0 && (byHand || preview || !quietWhileMicInUse || !Microphone.inUseByOthers())
        // Wake the audio while the mallet is in the air, so the first knock
        // after a quiet lands with the mallet rather than a moment after it.
        if audible { sound.warm(for: delay) }
        // A press is read a moment into the swing, once a Force Touch trackpad
        // has felt how firm it is. A typed key has no time to spare.
        let feel = quick ? 0 : Self.liftDuration
        let swingTask = Task {
            try? await Task.sleep(for: .seconds(feel))
            guard !Task.isCancelled else { return }
            let deep = (press?.stage ?? 0) >= 2
            let (force, place) = touch(byHand: byHand, quick: quick, at: x,
                                       silence: full ? .infinity : ProcessInfo.processInfo.systemUptime + delay - feel - lastImpact)
            // The knock is made while the mallet is in the air.
            let knock = sound.synthesize(force: force, place: place)
            try? await Task.sleep(for: .seconds(delay - feel))
            guard !Task.isCancelled else { return }
            if handSwing?.serial == serial { handSwing = nil }
            let samples = await knock.value
            let now = ProcessInfo.processInfo.systemUptime
            bloom = full ? 1 : Self.bloom(afterSilence: now - lastImpact)
            lastImpact = now
            impacts += 1
            if audible {
                sound.play(samples, volume: Float(volume), bloom: Float(bloom))
            }
            if byHand && !preview {
                // A Force Touch trackpad taps back as the mallet lands, harder
                // for a deep press. macOS plays it only while a finger rests
                // on the trackpad, as it still does when the knock is pressed.
                NSHapticFeedbackManager.defaultPerformer.perform(deep ? .levelChange : .generic,
                                                                 performanceTime: .now)
                speak()
            }
        }
        if byHand && !preview { handSwing = (serial, swingTask) }
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
            let bloom = Self.bloom(afterSilence: now - lastImpact)
            lastImpact = now
            sound.play(samples, volume: Float(volume), bloom: Float(bloom))
        }
    }

    /// How hard and where a knock lands. A firm click lands harder and a deep
    /// one hardest; a hand in a hurry lands lighter, and a typed key lighter
    /// still. A click off the strike point lands toward the edge.
    private func touch(byHand: Bool, quick: Bool, at x: Double?, silence: Double) -> (force: Float, place: Float) {
        let rested = Float(Self.bloom(afterSilence: silence))
        var force: Float
        if quick {
            force = 0.36 + 0.2 * rested + .random(in: -0.05...0.05)
        } else if byHand, let press {
            force = press.stage >= 2 ? 0.95 : 0.4 + 0.4 * press.pressure
            force *= 0.85 + 0.15 * rested
        } else {
            force = (0.58 + .random(in: -0.07...0.07)) * (0.85 + 0.15 * rested)
        }
        press = nil
        // A quarter of the fish's width off the strike point is the edge.
        let place = x.map { Float(($0 - pack.strike.x) / 0.25) } ?? .random(in: -0.2...0.2)
        return (min(max(force, 0.1), 1), min(max(place, -1), 1))
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

    /// Place the knock where the fish sits: `x` runs from 0 at the screen's
    /// left edge to 1 at its right, `y` from 0 at the bottom to 1 at the top.
    func heard(at x: Double, _ y: Double) {
        sound.place(x: Float(x), y: Float(y))
    }

    /// The longer the quiet before a knock, the more fully it rings: none of
    /// the hall after a rushed knock, all of it after twenty seconds of quiet.
    static func bloom(afterSilence seconds: Double) -> Double {
        let x = (log(seconds) - log(0.8)) / (log(20) - log(0.8))
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
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
            if !allSkins.contains(where: { $0.id == skin }) { skin = "" } else { loadSkin() }
        }
    }

    private func loadSkin() {
        pack = (allSkins.first { $0.id == skin } ?? SkinOption.woodenFish).pack
        menuIcon = pack.idle.menuBarIcon()
        sound.use(voice: pack.voice, space: Float(space))
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

    /// Light a stick of incense: one knock as it is lit, quiet while it burns,
    /// three knocks as it goes out. The first is 止静, the start of a sitting,
    /// and rings fully even just after a knock. Nothing is counted or kept.
    func lightIncense(minutes: Int) {
        incenseTask?.cancel()
        let stick = Incense(lit: .now, duration: Double(minutes) * 60)
        incense = stick
        endCall()
        knock(byHand: false, full: true)
        incenseTask = Task { [weak self] in
            // The continuous clock keeps burning while the Mac sleeps.
            try? await Task.sleep(for: .seconds(stick.duration))
            guard let self, !Task.isCancelled else { return }
            // The spent stick stays while the ember dies and its last smoke
            // drifts away under the call. A new stick lit meanwhile ends
            // this one's.
            call()
            try? await Task.sleep(for: .seconds(Self.callLength))
            guard !Task.isCancelled else { return }
            incense = nil
        }
    }

    /// Put the incense out early, without a knock.
    func putOutIncense() {
        incenseTask?.cancel()
        incense = nil
        endCall()
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
        autoTask?.cancel()
        autoTask = nil
        callLanded = .infinity
        callTask = Task { [weak self] in
            for _ in 0..<3 {
                try? await Task.sleep(for: .seconds(Self.callBeat))
                guard let self, !Task.isCancelled else { return }
                let answered = max(TypingWatcher.lastEvent(.keyDown), TypingWatcher.lastEvent(.leftMouseDown))
                if answered > callLanded { return endCall() }
                strike(byHand: false, full: true)
                if callLanded == .infinity {
                    callLanded = ProcessInfo.processInfo.systemUptime + Self.impactDelay
                }
            }
            try? await Task.sleep(for: .seconds(Self.callLength - Self.callBeat * 3))
            guard let self, !Task.isCancelled else { return }
            callTask = nil
            callLanded = .infinity
            restartAuto()
        }
    }

    /// End a call before its last knock: you are here.
    private func endCall() {
        guard let callTask else { return }
        callTask.cancel()
        self.callTask = nil
        callLanded = .infinity
        restartAuto()
    }

    private func watchTyping() {
        if knockAsYouType || bell { typing.start(keyByKey: knockAsYouType) } else { typing.stop() }
    }

    /// A key went down, in some app. It knocks, if knocking as you type; and
    /// once you have typed long enough without a rest, the bell knocks instead.
    private func typed() {
        if callTask != nil, ProcessInfo.processInfo.systemUptime > callLanded {
            endCall()
        }
        let now = Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1e9
        if now - lastTyped > Self.rest { typingSince = now }
        lastTyped = now
        // A call already has your ear; the bell waits for the next key after it.
        if bell && callTask == nil && bellTask == nil && now - typingSince >= Self.bellAfter {
            typingSince = now
            hushUntil = now + Self.bellQuiet + Self.breaths
            autoTask?.cancel()
            autoTask = nil
            // A quiet first, so the bell isn't lost among other knocks, and
            // then it rings in full, as the hall's signal it is.
            bellTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.bellQuiet))
                guard let self, !Task.isCancelled else { return }
                if bell && callTask == nil { strike(byHand: false, full: true) }
                try? await Task.sleep(for: .seconds(Self.breaths))
                guard !Task.isCancelled else { return }
                bellTask = nil
                restartAuto()
            }
        } else if knockAsYouType && now >= hushUntil {
            knock(byHand: false, quick: true)
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

    private func restartAuto() {
        autoTask?.cancel()
        autoTask = nil
        guard autoKnock, callTask == nil, bellTask == nil, !resting else { return }
        autoTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let next = self.map({ fish in
                    var gap = fish.rhythm.gap(before: fish.rhythmStep, interval: fish.interval)
                    // 煞板: the last three knocks of a mala's turn slow down, each
                    // gap wider than the last, and the last rings fully into the quiet.
                    let left = fish.stopAt108 ? 108 - fish.autoRound : 0
                    if (1...3).contains(left) { gap = max(gap, fish.interval) * pow(1.5, Double(4 - left)) }
                    return (gap: gap, last: left == 1)
                }) else { return }
                try? await Task.sleep(for: .seconds(next.gap))
                guard let self, !Task.isCancelled else { return }
                knock(byHand: false, full: next.last)
                autoRound += 1
                rhythmStep += 1
                // One turn of the mala, then quiet. The quiet says the rest.
                if stopAt108 && autoRound >= 108 { autoKnock = false }
            }
        }
    }
}

/// The worn skin's knock and the room it rings in. Each knock is synthesized
/// as the mallet falls, for how hard and where it lands. It comes from where
/// the fish sits, placed around the listener, and on headphones it is rendered
/// for the ears. Every knock rings in the one hall, so a run of knocks builds
/// up in the room the way it would in a temple, rather than each in its own.
///
/// The engine runs only while a knock rings. A running engine holds the audio
/// output open, which keeps the Mac from idle sleep and costs CPU even in silence.
@MainActor
final class KnockSound {
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
    private var ringsUntil = 0.0
    private var quiet: Task<Void, Never>?
    /// Where the fish sits on its screen, and whether the knock goes to headphones.
    private var spot: (x: Float, y: Float) = (0.5, 0.5)
    private var headphones = false

    init() {
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
    func use(voice name: String?, space: Float) {
        let next = KnockSynth.resolve(name)
        guard next != voice || space != self.space else { return }
        // A new voice keeps the room ringing; only a new room starts it afresh.
        let room = space != self.space ? KnockSynth.Hall.Room(space: space) : nil
        voice = next
        self.space = space
        if let room { tail = room.tail }
        mix.use(room: room, gain: KnockSynth.Hall.gain(for: KnockSynth.reference(next), space: space))
    }

    /// Where the fish sits on its screen: `x` from 0 at the left edge to 1 at
    /// the right, `y` from 0 at the bottom to 1 at the top. Not all the way
    /// round: it is in front of you, a little to one side. Knocks still ringing
    /// move with it.
    func place(x: Float, y: Float) {
        spot = (min(max(x, 0), 1), min(max(y, 0), 1))
        // On headphones the knock is rendered for the ears, up and down as well
        // as across. Speakers get a gentle pan: rendered for ears, a knock at
        // the screen's edge comes out of one speaker alone.
        let azimuth = (spot.x * 2 - 1) * (headphones ? 0.7 : 0.25)
        let elevation = headphones ? (spot.y * 2 - 1) * 0.26 : 0
        dry.position = AVAudio3DPoint(x: sin(azimuth) * cos(elevation), y: sin(elevation),
                                      z: -cos(azimuth) * cos(elevation))
    }

    /// Render for the output in use. Checked as the engine starts, which it
    /// does after every quiet and after the output changes.
    private func route() {
        headphones = Headphones.inUse()
        environment.outputType = headphones ? .headphones : .externalSpeakers
        dry.renderingAlgorithm = headphones ? .HRTFHQ : .equalPowerPanning
        place(x: spot.x, y: spot.y)
    }

    /// Start synthesizing one knock of the worn voice, or of `voice`, while the mallet falls.
    func synthesize(force: Float, place: Float, voice: String? = nil) -> Task<[Float], Never> {
        let voice = voice ?? self.voice
        return Task.detached(priority: .userInitiated) {
            KnockSynth.knock(voice, force: force, place: place)
        }
    }

    /// Start the engine, if it is paused, for a knock due in `seconds`.
    /// Starting it takes a moment, best spent while the mallet is in the air.
    func warm(for seconds: Double) {
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
    func play(_ knock: [Float], volume: Float, bloom: Float) {
        guard knock.count > 1, volume > 0, start() else { return }
        let gain = volume * .random(in: 0.92...1.0)
        mix.add(knock, dry: gain * (0.8 + 0.2 * bloom), send: gain * (0.25 + 0.75 * bloom))
        let now = ProcessInfo.processInfo.systemUptime
        let rings = Double(knock.count) / Double(KnockSynth.sampleRate) + tail
        ringsUntil = max(ringsUntil, now + rings)
        pauseWhenQuiet()
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
