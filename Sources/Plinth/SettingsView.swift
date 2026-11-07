import PlinthCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            KnockingSettings().tabItem { Label("Knocking", systemImage: "hand.tap") }
            SkinSettings().tabItem { Label("Skins", systemImage: "paintpalette") }
            AboutSettings().tabItem { Label("Why a Fish", systemImage: "fish") }
        }
        .frame(width: 500)
    }
}

private struct KnockingSettings: View {
    @Environment(Fish.self) private var fish

    var body: some View {
        @Bindable var fish = fish
        Form {
            Section {
                // Let go of a slider and the fish knocks once, to hear it.
                LabeledContent("Volume") {
                    Slider(value: $fish.volume, in: 0...1) {
                        EmptyView()
                    } minimumValueLabel: {
                        VolumeEnd.end(loud: false)
                    } maximumValueLabel: {
                        VolumeEnd.end(loud: true)
                    } onEditingChanged: { editing in
                        if !editing { fish.preview() }
                    }
                }
                LabeledContent("Space") {
                    VStack(spacing: 3) {
                        // The volume's speakers, unseen, so the two tracks line up.
                        Slider(value: $fish.space, in: 0...1) {
                            EmptyView()
                        } minimumValueLabel: {
                            VolumeEnd.end(loud: false).hidden()
                        } maximumValueLabel: {
                            VolumeEnd.end(loud: true).hidden()
                        } onEditingChanged: { editing in
                            if !editing { fish.preview() }
                        }
                        HStack {
                            Text("Meditation room")
                            Spacer()
                            Text("Great hall")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Sound")
            } footer: {
                Text("The longer the quiet before a knock, the longer it rings.")
                    .settingsFootnote()
            }
            Section {
                Toggle("Knock on its own", isOn: $fish.autoKnock.animation(.snappy))
                // Only what applies: the pace and rhythm appear once it knocks.
                if fish.autoKnock {
                    LabeledContent("Every") {
                        HStack {
                            // Even steps in proportion, not in seconds: from 0.4 s to 0.8 s
                            // is as far as from 4 s to 8 s, a slow breath. Tenths of a second.
                            Slider(value: Binding(get: { log(fish.interval) }, set: {
                                let seconds = (exp($0) * 10).rounded() / 10
                                if seconds != fish.interval { fish.interval = seconds }
                            }), in: log(0.4)...log(8)) {
                                EmptyView()
                            } minimumValueLabel: {
                                Image(systemName: "hare").foregroundStyle(.secondary)
                            } maximumValueLabel: {
                                Image(systemName: "tortoise").foregroundStyle(.secondary)
                            }
                            Text("\(fish.interval, specifier: "%.1f") s")
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                    Picker("Rhythm", selection: $fish.rhythm) {
                        ForEach(Rhythm.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Stop after 108 knocks, one turn of a mala", isOn: $fish.stopAt108)
                }
            } header: {
                Text("Auto-Knock")
            } footer: {
                if fish.autoKnock {
                    Text(fish.rhythm.about).settingsFootnote()
                }
            }
            Section {
                Toggle("Knock as you type", isOn: $fish.knockAsYouType)
                Toggle("Knock after long typing", isOn: $fish.bell)
                if Microphone.canTell {
                    Toggle("Quiet while a microphone is in use", isOn: $fish.quietWhileMicInUse)
                }
                LabeledContent("Mallet key") { MalletKeyField() }
            } header: {
                Text("While You Work")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Each key you press, in any app, knocks once. Plinth never learns which key, and needs no permission.")
                        .settingsFootnote()
                    Text("After half an hour of typing with no three-minute rest, the fish falls quiet for three seconds, then knocks once with a held mallet. Typed knocks and auto-knock stay quiet for three breaths, about 15 seconds. Nothing is counted or kept.")
                        .settingsFootnote()
                    if Microphone.canTell {
                        Text("While another app listens to a microphone, as in a call, only a knock by hand sounds. Plinth never listens itself.")
                            .settingsFootnote()
                    }
                    Text("A key, a foot pedal or a Stream Deck button can be the mallet: press it in any app and the fish is knocked by hand. An F-key can stand alone; any other key needs two modifiers, one of them ⌘ or ⌃, so ⌘C, ⌃C and the like keep working.")
                        .settingsFootnote()
                }
            }
            Section("The Fish") {
                Picker("Size", selection: $fish.size) {
                    ForEach(FishSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Placement", selection: $fish.placement) {
                    ForEach(Placement.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Launch at login", isOn: $fish.launchAtLogin)
            }
            if Updates.shared.available {
                UpdateSettings()
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The mallet key: click, then press the key to record it; Esc stops.
private struct MalletKeyField: View {
    @Environment(Fish.self) private var fish
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 4) {
            Button {
                if monitor == nil { record() } else { stop() }
            } label: {
                if monitor != nil {
                    Text("Press a key…")
                } else if let key = fish.malletKey {
                    Text(verbatim: key.title).monospaced()
                } else {
                    Text("Record Key")
                }
            }
            if fish.malletKey != nil && monitor == nil {
                Button {
                    _ = fish.useMalletKey(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Clear")
                .accessibilityLabel("Clear")
            }
        }
        .onDisappear { stop() }
    }

    private func record() {
        fish.holdMalletKey(false)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 /* Esc */, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                stop()
            } else if let key = MalletKey(event), fish.useMalletKey(key) {
                stop()
                // The mallet's first knock, to hear it land.
                fish.knock()
            } else {
                // A plain key would stop typing it, or another app holds the key.
                NSSound.beep()
            }
            return nil
        }
    }

    private func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        fish.holdMalletKey(true)
    }
}

private struct UpdateSettings: View {
    var body: some View {
        @Bindable var updates = Updates.shared
        Section {
            Toggle("Check for updates automatically", isOn: $updates.checksAutomatically)
        } header: {
            Text("Updates")
        } footer: {
            Text("Once a day, Plinth asks GitHub whether there is a newer version, and asks you before installing it. Nothing about you or your Mac is sent.")
                .settingsFootnote()
        }
    }
}

/// Every skin as a thumbnail; click one to wear it.
private struct SkinSettings: View {
    @Environment(Fish.self) private var fish

    var body: some View {
        Form {
            Section("Built In") { grid(SkinOption.builtIn) }
            Section {
                if fish.skins.isEmpty {
                    Text("No skins of your own yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    grid(fish.skins, exportable: true)
                }
                HStack {
                    Button("Add Skins…") { fish.addSkins() }
                    Button("Open Skins Folder") { NSWorkspace.shared.open(Fish.skinsDirectory) }
                    Spacer()
                    Button("Browse More Skins…") { NSWorkspace.shared.open(Fish.moreSkins) }
                }
            } header: {
                Text("Your Skins")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Click a skin to wear it. One of your own can be a single image or a folder of frames; right-click it to export a .plinthskin to share.")
                        .settingsFootnote()
                    Link("How to Make a Skin", destination: Fish.skinGuide)
                        .font(.footnote)
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 520)
    }

    private func grid(_ options: [SkinOption], exportable: Bool = false) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(options) { option in
                SkinTile(option: option, selected: option.id == fish.skin) {
                    fish.skin = option.id
                    // A knock in the skin's own voice.
                    fish.preview()
                }
                    .contextMenu {
                        // A folder skin goes out as one .plinthskin file; a single image is shared as it is.
                        if exportable, (try? Fish.skinsDirectory.appending(path: option.id).resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                            Button("Export as .plinthskin…") { fish.export(option) }
                        }
                    }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SkinTile: View {
    let option: SkinOption
    let selected: Bool
    let choose: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: choose) {
            VStack(spacing: 4) {
                Image(nsImage: option.pack.idle.thumbnail(side: 152))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .scaleEffect(hovering ? 1.06 : 1)
                Text(option.title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(selected ? Color.accentColor.opacity(0.15) : hovering ? Color.primary.opacity(0.05) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(TileButtonStyle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .help(option.title)
    }
}

/// A tile gives a little under the pointer as it is pressed.
private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

/// The speakers at the ends of the volume slider.
private enum VolumeEnd {
    /// One type for both ends, as a slider's two labels must be.
    static func end(loud: Bool) -> some View {
        Image(systemName: loud ? "speaker.wave.3.fill" : "speaker.fill").foregroundStyle(.secondary)
    }
}

/// A hanging scroll: the ink fish in an ensō on rice paper, and the rule
/// that explains it written top to bottom, right to left, with its source
/// and a seal. It stays paper in Dark Mode too; ink needs a light ground.
private struct AboutSettings: View {
    static let paper = Color(red: 0.953, green: 0.933, blue: 0.890)
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.14)
    static let cinnabar = Color(red: 0.70, green: 0.20, blue: 0.15)

    @Environment(Fish.self) private var fish
    private let inkFish = SkinOption.inkFish

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ZStack {
                    Enso(color: Self.ink, opacity: 0.3)
                        .frame(width: 200, height: 200)
                    Image(nsImage: inkFish.pack.idle)
                        .resizable()
                        .frame(width: 176, height: 176)
                        // The fish sits low in its sprite, under the mallet's arc.
                        .offset(y: -24)
                        // The fish on the scroll is a fish: knock it and it sounds.
                        .onTapGesture { fish.knockPainting() }
                        // VoiceOver reads it as a button that knocks, and can press it.
                        .accessibilityElement()
                        .accessibilityLabel("Knock")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { fish.knockPainting() }
                }
                .padding(.top, 52)
                .frame(maxWidth: .infinity)
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 14) {
                        Column(text: Zen.whyFish.source.trimmingCharacters(in: CharacterSet(charactersIn: "《》")),
                               size: 11, color: Self.ink.opacity(0.5))
                        Seal(text: "常醒")
                    }
                    .padding(.top, 92)
                    ForEach(Array(Self.columns(Zen.whyFish.text).enumerated().reversed()), id: \.offset) { _, line in
                        Column(text: line, size: 19, color: Self.ink.opacity(0.88))
                    }
                }
                .padding(.top, 40)
                .padding(.trailing, 44)
            }
            Spacer(minLength: 24)
            Text("Knocking earns no merit.")
                .font(.system(size: 11, design: .serif))
                .tracking(1.5)
                .foregroundStyle(Self.ink.opacity(0.38))
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 380)
        .background(Self.paper)
        .environment(\.colorScheme, .light)
    }

    /// One column per clause, without punctuation, as on a scroll.
    private static func columns(_ text: String) -> [String] {
        text.split(whereSeparator: { "，。、；：！？\n".contains($0) }).map(String.init)
    }
}

/// Characters stacked top to bottom.
private struct Column: View {
    let text: String
    let size: CGFloat
    let color: Color

    var body: some View {
        VStack(spacing: size * 0.32) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
            }
        }
        .font(.custom("Songti SC", size: size))
        .foregroundStyle(color)
    }
}

/// A small cinnabar seal, its characters carved out in white.
private struct Seal: View {
    let text: String

    var body: some View {
        VStack(spacing: 1) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
            }
        }
        .font(.custom("Songti SC", size: 10).weight(.bold))
        .foregroundStyle(AboutSettings.paper)
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .background(AboutSettings.cinnabar, in: RoundedRectangle(cornerRadius: 2))
        .opacity(0.9)
    }
}

/// One brushstroke round, open where the brush lifted. The brush lands at the
/// lower left, goes round clockwise, thins, and runs dry: its hairs part
/// into streaks and give out one by one before the circle closes.
private struct Enso: View {
    let color: Color
    let opacity: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let thickest = radius * 0.15
            /// A point on the stroke at t (0 where the brush lands, 1 where
            /// the circle would close), `offset` out from its middle.
            func point(_ t: Double, _ offset: Double) -> CGPoint {
                let angle = 2.3 + 2 * Double.pi * 0.9 * t // radians, y down: from the lower left
                let r = radius - thickest / 2 + radius * 0.012 * sin(t * 9 + 0.5) + offset
                return CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            }
            func width(_ t: Double) -> Double { thickest * pow(max(0, 1 - t), 1.1) }

            // The body of the stroke, thinning as the ink runs out.
            let wet = (0...180).map { 0.8 * Double($0) / 180 }
            var body = Path()
            body.addLines(wet.map { point($0, width($0) / 2) } + wet.reversed().map { point($0, -width($0) / 2) })
            body.closeSubpath()
            // Where the brush lands it presses down, a blunt drop along the stroke.
            let landing = point(0.012, 0)
            let along = atan2(point(0.03, 0).y - landing.y, point(0.03, 0).x - landing.x)
            body.addPath(Path(ellipseIn: CGRect(x: -thickest * 0.75, y: -thickest * 0.6,
                                                width: thickest * 1.5, height: thickest * 1.2)),
                         transform: CGAffineTransform(translationX: landing.x, y: landing.y).rotated(by: along))
            context.fill(body, with: .color(color))
            // Then it runs dry: a few hairs carry on alone and give out one by one.
            for (across, end) in [(-0.45, 0.86), (-0.2, 0.97), (0.05, 0.91), (0.3, 0.95), (0.48, 0.84)] {
                var hair = Path()
                hair.addLines((0...60).map { point(0.55 + (end - 0.55) * Double($0) / 60, across * width(0.55)) })
                context.stroke(hair, with: .color(color),
                               style: StrokeStyle(lineWidth: thickest * 0.09, lineCap: .round))
            }
        }
        // Overlaps don't darken: the stroke is one wash of ink.
        .compositingGroup()
        .opacity(opacity)
    }
}

private extension Text {
    func settingsFootnote() -> some View {
        // A Form footer is drawn flush right; a note reads better from the left.
        font(.footnote).foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
