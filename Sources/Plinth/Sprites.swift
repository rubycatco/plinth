import PlinthCore
import SwiftUI

extension Color {
    init(_ glow: SkinGlow) {
        self.init(red: glow.red, green: glow.green, blue: glow.blue)
    }
}

extension NSImage {
    /// The image's visible part, squared and scaled to fit the menu bar:
    /// a skin frame has a lot of empty space above the figure.
    func menuBarIcon(side: CGFloat = 18) -> NSImage {
        guard let visible = cgImage(forProposedRect: nil, context: nil, hints: nil)?.visiblePart() else { return self }
        let fit = side / CGFloat(max(visible.width, visible.height))
        let size = CGSize(width: CGFloat(visible.width) * fit, height: CGFloat(visible.height) * fit)
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            NSImage(cgImage: visible, size: .zero).draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                                                                   width: size.width, height: size.height))
            return true
        }
    }
}

extension NSImage {
    private static var thumbnailsKey: UInt8 = 0

    /// The figure alone, without the empty air its frame keeps for the
    /// mallet, so a tile or menu item shows the skin rather than space. Kept,
    /// as finding the figure reads every pixel. Kept on the source image
    /// itself, so it goes when the skins are read afresh and the old images do.
    func thumbnail(side: CGFloat) -> NSImage {
        var made = objc_getAssociatedObject(self, &Self.thumbnailsKey) as? [CGFloat: NSImage] ?? [:]
        if let done = made[side] { return done }
        let thumbnail = menuBarIcon(side: side)
        // An image that could not be cropped comes back as itself; holding it would keep it forever.
        if thumbnail !== self {
            made[side] = thumbnail
            objc_setAssociatedObject(self, &Self.thumbnailsKey, made, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return thumbnail
    }
}

/// The worn skin as the fish is knocked: the shared `SpriteFish`, following
/// this fish's swings. Only this view reads them, so only it redraws for them.
struct WornFish: View {
    let pack: SkinPack
    let side: CGFloat
    @Environment(Fish.self) private var fish

    var body: some View {
        SpriteFish(pack: pack, side: side, swing: fish.swing, impacts: fish.impacts, bloom: fish.bloom)
    }
}
