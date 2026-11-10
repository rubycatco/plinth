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

extension SkinPack {
    /// The figure with its mallet lying on it, as `SpriteFish` draws a mallet
    /// a call left on the wood, small enough for the menu bar. The two share
    /// the icon's square, so the figure is a little smaller than it is alone.
    func menuBarIcon(malletDown: Bool, side: CGFloat = 18) -> NSImage {
        guard malletDown, let figure = idle.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let stick = (mallet ?? Sprite.mallet).cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return idle.menuBarIcon(side: side)
        }
        // One frame, and room past its right edge for the mallet's grip.
        let frame = CGFloat(figure.width), size = frame * Sprite.malletSize
        guard let ctx = CGContext(data: nil, width: Int(frame * 1.25), height: Int(frame), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return idle.menuBarIcon(side: side)
        }
        ctx.interpolationQuality = .high
        ctx.draw(figure, in: CGRect(x: 0, y: 0, width: frame, height: frame))
        // The grip, from the frame's lower left: up and to the right of the
        // strike point, with the head on it.
        let reach = (Sprite.malletGrip.x - Sprite.malletHead.x) * size
        let a = Sprite.strikeDegrees * .pi / 180
        let grip = CGPoint(x: strike.x * frame + reach * cos(a), y: (1 - strike.y) * frame + reach * sin(a))
        ctx.translateBy(x: grip.x, y: grip.y)
        ctx.rotate(by: a)
        ctx.draw(stick, in: CGRect(x: -Sprite.malletGrip.x * size, y: -(1 - Sprite.malletGrip.y) * size, width: size, height: size))
        guard let both = ctx.makeImage() else { return idle.menuBarIcon(side: side) }
        return NSImage(cgImage: both, size: .zero).menuBarIcon(side: side)
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
