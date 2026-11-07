import PlinthCore
import SwiftUI

@main
struct PlinthApp: App {
    @State private var fish = Fish()

    var body: some Scene {
        WindowGroup {
            FishScreen()
                .environment(fish)
        }
    }
}

/// The fish on rice paper, alone. Like the Mac's, it keeps no count and shows
/// no clock, so the status bar keeps out of the way too. A small palette in
/// the corner lays the skins out along the foot of the paper.
struct FishScreen: View {
    /// The rice paper of the Mac's Settings › Why a Fish. It stays paper in
    /// Dark Mode too; ink needs a light ground.
    static let paper = Color(red: 0.953, green: 0.933, blue: 0.890)
    /// The ink of the little written on the paper, dark in Dark Mode too.
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.11)

    @Environment(Fish.self) private var fish
    /// A finger on the fish, which knocks once as it goes down.
    @GestureState private var pressed = false
    /// Whether the skins are laid out to choose from.
    @State private var choosing = false

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { screen in
                let page = Self.page(in: screen)
                // The Mac's largest fish, or smaller on a narrow page.
                let side = min(300, min(page.width, page.height) * 0.8)
                SpriteFish(pack: fish.pack, side: side, swing: fish.swing, impacts: fish.impacts, bloom: fish.bloom)
                    .frame(width: side, height: side)
                    .contentShape(Rectangle())
                    // The mallet swings as the finger goes down, as a drum answers
                    // a stick, not when it lifts.
                    .gesture(DragGesture(minimumDistance: 0).updating($pressed) { value, pressed, _ in
                        guard !pressed else { return }
                        pressed = true
                        fish.knock(at: value.startLocation.x / side)
                    })
                    // VoiceOver reads it as a button that knocks, and can press it.
                    .accessibilityElement()
                    .accessibilityLabel("Knock")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { fish.knock(at: fish.pack.strike.x) }
                    .position(x: page.midX, y: page.midY)
                    // As the fold comes and goes, the fish moves over rather than jumps.
                    .animation(.smooth(duration: 0.4), value: page.origin)
            }
            .overlay(alignment: .bottomTrailing) {
                Button { choosing.toggle() } label: {
                    Image(systemName: choosing ? "chevron.down" : "paintpalette")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(Self.ink.opacity(0.4))
                .padding(.trailing, 8)
                .accessibilityLabel("Skin")
                .accessibilityAddTraits(choosing ? .isSelected : [])
            }
            if choosing {
                SkinStrip()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Self.paper)
        .statusBarHidden()
        // The fish rises as the skins come up, and stays to be knocked.
        .animation(.smooth(duration: 0.3), value: choosing)
    }

    /// The part of the paper the fish sits on: all of it, or, while the fold
    /// of a half-open iPhone Duo divides it, the part past the fold. Held like
    /// a book, that is the right-hand page; set down like a laptop, the half
    /// that lies on the table, where a knock doesn't rock the phone.
    private static func page(in screen: GeometryProxy) -> CGRect {
        let paper = CGRect(origin: .zero, size: screen.size)
        guard #available(iOS 27.1, *), let fold = screen.reservedRegions(kind: .division).first?.frame else {
            return paper
        }
        return fold.height > fold.width
            ? CGRect(x: fold.maxX, y: 0, width: paper.maxX - fold.maxX, height: paper.height)
            : CGRect(x: 0, y: fold.maxY, width: paper.width, height: paper.maxY - fold.maxY)
    }
}

/// The skins that ship with the app, in a row along the foot of the paper,
/// each over its name. Choosing one wears it, and the fish knocks once in
/// its voice.
struct SkinStrip: View {
    /// Each skin's figure, without the air its frame keeps for the mallet:
    /// found once, as finding it reads every pixel.
    private static let figures = Dictionary(uniqueKeysWithValues: SkinOption.builtIn.map { option in
        (option.id, option.pack.idle.cgImage?.visiblePart().map { UIImage(cgImage: $0) } ?? option.pack.idle)
    })
    /// The margin before the first tile, and the gap between tiles.
    private static let margin = 12.0
    private static let gap = 4.0

    @Environment(Fish.self) private var fish

    var body: some View {
        ScrollViewReader { row in
            ScrollView(.horizontal) {
                HStack(spacing: Self.gap) {
                    ForEach(SkinOption.builtIn) { option in
                        tile(option, worn: option.id == fish.skin)
                    }
                }
                .padding(.horizontal, Self.margin)
            }
            .scrollIndicators(.hidden)
            // The row ends where the line above it ends. In landscape it would
            // otherwise run on into the screen's side margins, past its half tile.
            .clipped()
            .onAppear { row.scrollTo(fish.skin, anchor: .center) }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { FishScreen.ink.opacity(0.1).frame(height: 1) }
    }

    private func tile(_ option: SkinOption, worn: Bool) -> some View {
        Button {
            fish.skin = option.id
            fish.knock(preview: true)
        } label: {
            VStack(spacing: 6) {
                Image(uiImage: Self.figures[option.id] ?? option.pack.idle)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                Text(option.title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .containerRelativeFrame(.horizontal) { width, _ in Self.tileWidth(across: width) }
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(FishScreen.ink.opacity(worn ? 0.07 : 0)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(FishScreen.ink.opacity(worn ? 0.9 : 0.55))
        .accessibilityAddTraits(worn ? .isSelected : [])
        .id(option.id)
    }

    /// Tiles of 76 points or more: as many whole ones as fit across the row,
    /// and half of one more at its edge, so the row shows that it goes on.
    private static func tileWidth(across width: CGFloat) -> CGFloat {
        let least = 76.0
        let whole = ((width - margin - least / 2) / (least + gap)).rounded(.down)
        return max(least, (width - margin - gap * whole) / (whole + 0.5))
    }
}
