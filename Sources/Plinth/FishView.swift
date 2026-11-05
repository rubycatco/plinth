import SwiftUI

/// Moves the borderless panel while the fish is dragged.
@MainActor enum PanelMover {
    static weak var panel: NSPanel?
    /// Called when a drag ends, to keep the fish on a screen.
    static var onDrop: () -> Void = {}
    private static var start: (mouse: NSPoint, origin: NSPoint)?

    /// Start moving, `travel` after the press went down, in view coordinates.
    static func begin(after travel: CGSize) {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        start = (NSPoint(x: mouse.x - travel.width, y: mouse.y + travel.height), panel.frame.origin)
    }

    static func drag() {
        guard let panel, let start else { return }
        let mouse = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: start.origin.x + mouse.x - start.mouse.x,
                                     y: start.origin.y + mouse.y - start.mouse.y))
    }

    static func end() {
        guard start != nil else { return }
        start = nil
        onDrop()
    }
}

struct FishView: View {
    @Environment(Fish.self) private var fish
    /// The press on the fish: it knocks as it goes down, and becomes a move
    /// once the pointer travels.
    @GestureState private var grip = Grip.none

    private enum Grip { case none, pressed, moving }

    var body: some View {
        let side = fish.size.side
        VStack(spacing: 0) {
            SpriteFish(pack: fish.pack, side: side)
                .frame(width: side, height: side)
                // The mallet swings as the press goes down, as a drum answers a
                // stick, not when the click lets go. A press that turns into
                // a drag before the mallet lands takes the swing back.
                .gesture(DragGesture(minimumDistance: 0)
                    .updating($grip) { value, grip, _ in
                        if grip == .none {
                            grip = .pressed
                            fish.knock(at: value.startLocation.x / side)
                        }
                        if grip == .pressed, hypot(value.translation.width, value.translation.height) >= 3 {
                            grip = .moving
                            fish.callOff()
                            PanelMover.begin(after: value.translation)
                        }
                        if grip == .moving { PanelMover.drag() }
                    }
                    .onEnded { _ in PanelMover.end() })
                .contextMenu { FishMenu() }
                // Drop a .plinthskin, a skin folder or an image on the fish to wear it.
                .dropDestination(for: URL.self) { urls, _ in
                    fish.install(urls.filter(\.isFileURL))
                    return true
                }
                .help("Click to knock · Drag to move · Right-click for options")
                // The censer stands left of the pedestal, a touch behind it.
                .background(alignment: .topLeading) {
                    if let incense = fish.incense {
                        IncenseView(incense: incense, side: side)
                            .offset(x: -side * IncenseView.lead)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 1.2), value: fish.incense)
            caption
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.4), value: fish.notice)
    }

    /// The fish's few words, when it has something to say. Otherwise nothing.
    @ViewBuilder private var caption: some View {
        if let notice = fish.notice {
            QuoteView(quote: notice.quote)
                // Both the question and its source fade; the bubble keeps
                // their space, but VoiceOver has no hidden words to read.
                .opacity(notice.silent ? 0 : 1)
                .accessibilityHidden(notice.silent)
                .bubble()
        }
    }
}

struct QuoteView: View {
    let quote: Quote

    var body: some View {
        VStack(spacing: 3) {
            Text(quote.text)
                .font(.system(size: 12, design: .serif))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(quote.source)")
                .font(.system(size: 10, design: .serif))
                .foregroundStyle(.secondary)
        }
    }
}

private extension View {
    func bubble() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9))
            // Rises a little into place as it appears, and sinks as it goes.
            .transition(.opacity.combined(with: .offset(y: 4)).combined(with: .scale(scale: 0.97, anchor: .top)))
    }
}

/// The menu bar item shows the skin being worn.
struct MenuBarIcon: View {
    @Environment(Fish.self) private var fish

    var body: some View {
        Image(nsImage: fish.menuIcon).accessibilityLabel("Plinth")
    }
}

/// The skins that ship with the app, then any in the skins folder, each
/// beside a small picture of itself. Choosing one knocks once in its voice.
struct SkinPicker: View {
    @Environment(Fish.self) private var fish

    var body: some View {
        let wear = Binding(get: { fish.skin }, set: { fish.skin = $0; fish.preview() })
        Picker("Skin", selection: wear) {
            ForEach(SkinOption.builtIn) { item($0) }
            if !fish.skins.isEmpty {
                Divider()
                ForEach(fish.skins) { item($0) }
            }
        }
        .pickerStyle(.inline)
        // The menu it sits in already says Skin.
        .labelsHidden()
    }

    private func item(_ option: SkinOption) -> some View {
        Label {
            Text(option.title)
        } icon: {
            Image(nsImage: option.pack.idle.thumbnail(side: 16))
        }
        .labelStyle(.titleAndIcon)
        .tag(option.id)
    }
}

/// Shared by the menu bar item and the fish's right-click menu.
struct FishMenu: View {
    @Environment(Fish.self) private var fish
    @Environment(\.openSettings) private var openSettings

    /// The paces the menu offers; Settings can set any other.
    private static let paces = [6.0, 2.0, 1.0, 0.5]

    var body: some View {
        @Bindable var fish = fish
        Button("Knock") { fish.knock() }
        Divider()
        Toggle("Auto-Knock", isOn: $fish.autoKnock)
        Picker("Pace", selection: $fish.interval) {
            // About one breath out: a knock to each, to follow the breath by.
            Text("With the breath · every 6 s").tag(6.0)
            Text("Slow · every 2 s").tag(2.0)
            Text("Moderate · every 1 s").tag(1.0)
            Text("Fast · every 0.5 s").tag(0.5)
            // A pace set in Settings, so the menu still shows what is chosen.
            if !Self.paces.contains(fish.interval) {
                Divider()
                Text("Every \(fish.interval, specifier: "%.1f") s").tag(fish.interval)
            }
        }
        Picker("Rhythm", selection: $fish.rhythm) {
            ForEach(Rhythm.allCases) { Text($0.title).tag($0) }
        }
        Divider()
        Toggle("Knock as You Type", isOn: $fish.knockAsYouType)
        if fish.incense == nil {
            Menu("Light Incense") {
                ForEach(IncenseLength.allCases) { length in
                    Button(length.title) { fish.lightIncense(length) }
                }
            }
        } else {
            Button("Put Out the Incense") { fish.putOutIncense() }
        }
        Divider()
        Picker("Placement", selection: $fish.placement) {
            ForEach(Placement.allCases) { Text($0.title).tag($0) }
        }
        Menu("Skin") {
            SkinPicker()
            Divider()
            Button("Add Skins…") { fish.addSkins() }
            Button("Open Skins Folder") { NSWorkspace.shared.open(Fish.skinsDirectory) }
            Button("Browse More Skins…") { NSWorkspace.shared.open(Fish.moreSkins) }
        }
        Divider()
        let updates = Updates.shared
        if updates.available {
            Button(updates.waiting ? "Update Available…" : "Check for Updates…") { updates.check() }
                .disabled(!updates.canCheck)
        }
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Plinth") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
