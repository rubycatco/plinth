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
/// the corner lays the skins out along the foot of the paper, or, while the
/// fold of a half-open iPhone Duo divides it, across the page the fish isn't on.
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
        GeometryReader { paper in
            let (_, spare, fold) = Self.pages(in: paper)
            VStack(spacing: 0) {
                GeometryReader { screen in
                    let page = Self.pages(in: screen).fish
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
                        // A chevron to send the strip back down; a page of skins
                        // goes nowhere, so the palette stays, filled while it's open.
                        Image(systemName: !choosing ? "paintpalette" : spare == nil ? "chevron.down" : "paintpalette.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(Self.ink.opacity(0.4))
                    .padding(.trailing, 8)
                    .accessibilityLabel("Skin")
                    .accessibilityAddTraits(choosing ? .isSelected : [])
                }
                if choosing && spare == nil {
                    SkinStrip()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // Folded half shut, the paper shows a faint crease along the fold,
            // as rice paper does once it has been folded in half. The crease
            // fades in and out with the fold, as the fish moves over.
            .background {
                if let fold { Self.crease(along: fold) }
            }
            .overlay {
                if choosing, let spare {
                    SkinPage()
                        .frame(width: spare.width, height: spare.height)
                        .position(x: spare.midX, y: spare.midY)
                        .transition(.opacity)
                }
            }
            // Open the phone with the skins out, and they gather into the strip;
            // fold it half shut, and they spread across the spare page.
            .animation(.smooth(duration: 0.4), value: spare == nil)
        }
        .background(Self.paper)
        .statusBarHidden()
        // The fish rises as the skins come up, and stays to be knocked.
        .animation(.smooth(duration: 0.3), value: choosing)
    }

    /// The part of the paper the fish sits on: all of it, or, while the fold
    /// of a half-open iPhone Duo divides it, the part past the fold. Held like
    /// a book, that is the right-hand page; set down like a laptop, the half
    /// that lies on the table, where a knock doesn't rock the phone. The part
    /// before the fold is spare: the left-hand page, or the half that stands up.
    /// The fold between them comes too, whole: it runs from edge to edge of the
    /// screen, past the paper's margins.
    private static func pages(in screen: GeometryProxy) -> (fish: CGRect, spare: CGRect?, fold: CGRect?) {
        let paper = CGRect(origin: .zero, size: screen.size)
        guard #available(iOS 27.1, *), let fold = screen.reservedRegions(kind: .division).first?.frame else {
            return (paper, nil, nil)
        }
        let (past, before) = fold.height > fold.width
            ? (CGRect(x: fold.maxX, y: 0, width: paper.maxX - fold.maxX, height: paper.height),
               CGRect(x: 0, y: 0, width: fold.minX, height: paper.height))
            : (CGRect(x: 0, y: fold.maxY, width: paper.width, height: paper.maxY - fold.maxY),
               CGRect(x: 0, y: 0, width: paper.width, height: fold.minY))
        // In Split View each app has a page to itself, which the fold only
        // grazes at the edge: the left-hand app has no paper past the fold, the
        // right-hand one none before it. Then the paper is one page, less that
        // edge. Room is told by size, as CGRect's width and height are never negative.
        let room = { (page: CGRect) in page.size.width > 0 && page.size.height > 0 }
        guard room(before) else { return (past, nil, nil) }
        guard room(past) else { return (before, nil, nil) }
        return (past, before, fold)
    }

    /// A crease down the middle of the fold: a fine line where the fibres gave,
    /// a hair of light past it, and a little shade from the halves either side.
    private static func crease(along fold: CGRect) -> some View {
        let upright = fold.height > fold.width
        // Points from the middle of the fold, as a share of its breadth.
        let at = { (points: CGFloat) in 0.5 + points / (upright ? fold.width : fold.height) }
        return LinearGradient(stops: [
            .init(color: ink.opacity(0), location: 0),
            .init(color: ink.opacity(0.01), location: 0.25),
            .init(color: ink.opacity(0.03), location: at(-1)),
            .init(color: ink.opacity(0.07), location: at(-1)),
            .init(color: ink.opacity(0.07), location: at(0)),
            .init(color: .white.opacity(0.5), location: at(0)),
            .init(color: .white.opacity(0.5), location: at(1)),
            .init(color: ink.opacity(0.03), location: at(1)),
            .init(color: ink.opacity(0.01), location: 0.75),
            .init(color: ink.opacity(0), location: 1),
        ], startPoint: upright ? .leading : .top, endPoint: upright ? .trailing : .bottom)
        .frame(width: fold.width, height: fold.height)
        .position(x: fold.midX, y: fold.midY)
    }
}

/// The skins that ship with the app, in a row along the foot of the paper.
struct SkinStrip: View {
    /// The margin before the first tile, and the gap between tiles, which a
    /// page of skins keeps too.
    static let margin = 12.0
    static let gap = 4.0

    @Environment(Fish.self) private var fish

    var body: some View {
        ScrollViewReader { row in
            ScrollView(.horizontal) {
                HStack(spacing: Self.gap) {
                    ForEach(SkinOption.builtIn) { option in
                        SkinTile(option: option)
                            .containerRelativeFrame(.horizontal) { width, _ in Self.tileWidth(across: width) }
                            .id(option.id)
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

    /// Tiles of 76 points or more: as many whole ones as fit across the row,
    /// and half of one more at its edge, so the row shows that it goes on.
    private static func tileWidth(across width: CGFloat) -> CGFloat {
        let least = 76.0
        let whole = ((width - margin - least / 2) / (least + gap)).rounded(.down)
        return max(least, (width - margin - gap * whole) / (whole + 0.5))
    }
}

/// The skins that ship with the app, across a page of their own: the one a
/// half-open iPhone Duo spares from the fish. A page holds them all at once,
/// with room for larger figures than the strip's.
struct SkinPage: View {
    var body: some View {
        ScrollView {
            // Tiles of 80 points or more: five across the left-hand page, and
            // seven across the half that stands up, three rows of them.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: SkinStrip.gap)], spacing: SkinStrip.gap) {
                ForEach(SkinOption.builtIn) { SkinTile(option: $0, figure: 64) }
            }
            .padding(SkinStrip.margin)
        }
        // In the middle of the page, unless there are more than it holds.
        .defaultScrollAnchor(.center)
        .scrollIndicators(.hidden)
    }
}

/// A skin to choose, its figure over its name. Choosing it wears it, and the
/// fish knocks once in its voice.
struct SkinTile: View {
    /// Each skin's figure, without the air its frame keeps for the mallet:
    /// found once, as finding it reads every pixel.
    private static let figures = Dictionary(uniqueKeysWithValues: SkinOption.builtIn.map { option in
        (option.id, option.pack.idle.cgImage?.visiblePart().map { UIImage(cgImage: $0) } ?? option.pack.idle)
    })

    let option: SkinOption
    /// The side of the square the figure stands in.
    var figure = 52.0
    @Environment(Fish.self) private var fish

    var body: some View {
        let worn = option.id == fish.skin
        Button {
            fish.skin = option.id
            fish.knock(preview: true)
        } label: {
            VStack(spacing: 6) {
                Image(uiImage: Self.figures[option.id] ?? option.pack.idle)
                    .resizable()
                    .scaledToFit()
                    .frame(width: figure, height: figure)
                Text(option.title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(FishScreen.ink.opacity(worn ? 0.07 : 0)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(FishScreen.ink.opacity(worn ? 0.9 : 0.55))
        .accessibilityAddTraits(worn ? .isSelected : [])
    }
}
