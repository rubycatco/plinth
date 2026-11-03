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
                LabeledContent("Volume") {
                    Slider(value: $fish.volume, in: 0...1) {
                        EmptyView()
                    } minimumValueLabel: {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                }
                Toggle("Knock as you type", isOn: $fish.knockAsYouType)
            } header: {
                Text("Knocking")
            } footer: {
                Text("Typing: each key you press, in any app, knocks once. Plinth only notices when a key goes down, never which key, so it needs no special permission.")
                    .settingsFootnote()
            }
            Section("Auto-Knock") {
                Toggle("Knock on its own", isOn: $fish.autoKnock)
                LabeledContent("Every") {
                    HStack {
                        Slider(value: $fish.interval, in: 0.4...4) {
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
                .disabled(!fish.autoKnock)
                Toggle("Stop after 108 knocks, one turn of a mala", isOn: $fish.stopAt108)
                    .disabled(!fish.autoKnock)
            }
            Section("Display") {
                Picker("Size", selection: $fish.size) {
                    ForEach(FishSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Placement", selection: $fish.placement) {
                    ForEach(Placement.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Launch at login", isOn: $fish.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
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
                    grid(fish.skins)
                }
                HStack {
                    Button("Add Skins…") { fish.addSkins() }
                    Button("Open Skins Folder") { NSWorkspace.shared.open(Fish.skinsDirectory) }
                }
            } header: {
                Text("Your Skins")
            } footer: {
                Text("A skin is a folder with idle.png, and optionally blink.png and hit.png (or numbered sequences like blink-1.png, blink-2.png), its own mallet.png and impact.png, and skin.json for its name, where the mallet lands, and its knock: wood, lacquer, ink, cartoon, pixel, jade, bowl, key, bamboo, stone, piston, or crt. A single image works too.")
                    .settingsFootnote()
            }
        }
        .formStyle(.grouped)
        .frame(height: 520)
    }

    private func grid(_ options: [SkinOption]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(options) { option in
                SkinTile(option: option, selected: option.id == fish.skin) { fish.skin = option.id }
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
                Image(nsImage: option.pack.idle)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
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
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .help(option.title)
    }
}

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: SkinOption.woodenFish.pack.idle)
                .resizable()
                .frame(width: 120, height: 120)
            QuoteView(quote: Zen.whyFish)
                .frame(maxWidth: 380)
            Text("Knocking earns no merit.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

private extension Text {
    func settingsFootnote() -> some View {
        font(.footnote).foregroundStyle(.secondary)
    }
}
