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
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return self }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return self }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        // Rows run top to bottom in memory, as CGImage cropping expects.
        var (minX, minY, maxX, maxY) = (w, h, -1, -1)
        for y in 0..<h {
            for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 24 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, let visible = cg.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1,
                                                                   height: maxY - minY + 1)) else { return self }
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

/// A skin to choose: one that ships with the app, or one in the skins folder.
struct SkinOption: Identifiable {
    /// "" for the wooden fish, "builtin/<folder>" for the others that ship
    /// with the app, or the file name in the skins folder. The wooden fish
    /// keeps the "" it had as the default, so a choice of it still holds.
    let id: String
    let title: String
    let pack: SkinPack

    /// The skin worn until another is chosen: the ink fish, in the same ink
    /// and paper as the icon, the disk image and Settings > Why a Fish.
    private static let defaultFolder = "ink-fish"

    /// The ink fish first, then the rest in folder order. Their names come
    /// from skin.json in English, and from Skins.strings, keyed by folder, in
    /// other languages.
    static let builtIn: [SkinOption] = {
        guard let dir = Bundle.main.url(forResource: "Skins", withExtension: nil) else { return [] }
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
            .sorted { ($0 == defaultFolder ? 0 : 1, $0) < ($1 == defaultFolder ? 0 : 1, $1) }
        return names.compactMap { name in
            guard let pack = SkinPack.load(dir.appending(path: name)) else { return nil }
            return SkinOption(id: name == "wooden-fish" ? "" : "builtin/\(name)", title: title(name, pack.name ?? name), pack: pack)
        }
    }()

    static let inkFish = builtIn.first { $0.id == "builtin/\(defaultFolder)" }
        ?? SkinOption(id: "builtin/\(defaultFolder)", title: title(defaultFolder, "Ink Fish"), pack: SkinPack(idle: NSImage()))

    private static func title(_ folder: String, _ english: String) -> String {
        Bundle.main.localizedString(forKey: folder, value: english, table: "Skins")
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
