import PlinthCore
import SwiftUI

/// A skin as the Mac draws it. `Skin` reads it; its frames are `NSImage`s.
typealias SkinPack = Skin<NSImage>

extension Skin<NSImage> {
    static func load(_ url: URL?) -> SkinPack? {
        load(url, image: NSImage.init(contentsOf:))
    }
}

/// What a file is on disk, cheap to read: enough to tell when a skin has
/// changed without decoding its images. The status-change time moves on
/// every write, rename or replacement, even one that keeps the old
/// modification date, as a Finder copy does.
struct FileStamp: Equatable {
    var name: String
    var inode: UInt64
    var size: Int64
    var changed: timespec

    static func == (a: FileStamp, b: FileStamp) -> Bool {
        a.name == b.name && a.inode == b.inode && a.size == b.size
            && a.changed.tv_sec == b.changed.tv_sec && a.changed.tv_nsec == b.changed.tv_nsec
    }

    /// The file itself, then, for a folder skin, each file in it.
    static func of(_ url: URL) -> [FileStamp] {
        guard let own = stamp(url) else { return [] }
        // Hidden files, such as Finder's .DS_Store, are not part of the skin.
        let inside = ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).filter { !$0.hasPrefix(".") }
        return [own] + inside.sorted().compactMap { stamp(url.appending(path: $0)) }
    }

    private static func stamp(_ url: URL) -> FileStamp? {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return nil }
        return FileStamp(name: url.lastPathComponent, inode: info.st_ino, size: info.st_size, changed: info.st_ctimespec)
    }
}

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

/// Shared sprites, and where the mallet's head and grip sit in its image.
enum Sprite {
    static let mallet = load("mallet")
    static let impact = load("impact")
    static let malletHead = UnitPoint(x: 0.169, y: 0.505)
    static let malletGrip = UnitPoint(x: 0.964, y: 0.505)
    /// Mallet image size as a fraction of the frame.
    static let malletSize = 0.6
    /// At impact the handle rises this far above horizontal toward the grip;
    /// at rest the mallet is lifted the skin's `raise` further around the grip.
    static let strikeDegrees = 15.0

    private static func load(_ name: String) -> NSImage {
        Bundle.main.url(forResource: name, withExtension: "png").flatMap(NSImage.init(contentsOf:)) ?? NSImage()
    }
}

struct SpriteFish: View {
    let pack: SkinPack
    let side: CGFloat
    @Environment(Fish.self) private var fish
    /// The sequence playing, blink or hit; a new serial plays it again.
    @State private var cue = Cue()
    @State private var lastHit = -Double.infinity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Cue: Equatable {
        var hit = false
        var serial = 0
    }

    var body: some View {
        let frames = [pack.idle] + (cue.hit ? pack.hit : pack.blink)
        let last = Double(frames.count - 1)
        // Into the sequence, a moment on its last frame, and back to idle.
        let (into, hold, back) = cue.hit ? (0.03 + 0.02 * last, 0.14, 0.2 + 0.05 * last) : (0.06 * last, 0.05, 0.08 * last)
        ZStack {
            Color.clear
                .keyframeAnimator(initialValue: 0.0, trigger: cue) { _, position in
                    FrameBlend(frames: frames, position: position)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(last, duration: into, timingCurve: .easeOut)
                        LinearKeyframe(last, duration: hold)
                        LinearKeyframe(0, duration: back, timingCurve: .easeInOut)
                    }
                }
                // Without a hit frame the figure gives a little under the
                // mallet, like wood, and springs back.
                .keyframeAnimator(initialValue: 0.0, trigger: fish.impacts) { [gives = pack.hit.isEmpty && !reduceMotion ? 1.0 : 0.0] content, give in
                    content.scaleEffect(x: 1 + 0.008 * give * gives, y: 1 - 0.02 * give * gives, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1, duration: 0.03)
                        SpringKeyframe(0, duration: 0.3, spring: .smooth)
                    }
                }
            impact
            mallet
        }
        .frame(width: side, height: side)
        .onChange(of: fish.impacts) {
            lastHit = ProcessInfo.processInfo.systemUptime
            cue = Cue(hit: true, serial: cue.serial + 1)
        }
        .task(id: pack.blink.isEmpty) {
            guard !pack.blink.isEmpty else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(.random(in: 3...6)))
                // Never blink over a knock that has just landed.
                if ProcessInfo.processInfo.systemUptime - lastHit > 0.8 {
                    cue = Cue(hit: false, serial: cue.serial + 1)
                }
            }
        }
    }

    /// The mallet hangs from its grip, which sits up and to the right of the
    /// strike point; all motion is rotation around the grip.
    private var mallet: some View {
        let size = side * Sprite.malletSize
        let reach = (Sprite.malletGrip.x - Sprite.malletHead.x) * size
        let a = Sprite.strikeDegrees * .pi / 180
        let grip = CGPoint(x: pack.strike.x * side + reach * cos(a), y: pack.strike.y * side - reach * sin(a))
        let hit = -Sprite.strikeDegrees, rest = hit + pack.raise
        let swing = fish.swing
        // A typed key goes straight down, with no lift, to land with the key.
        let quick = swing.quick
        // With Reduce Motion the mallet settles back without bouncing.
        let rebound: Spring = reduceMotion ? .smooth : .bouncy
        return Image(nsImage: pack.mallet ?? Sprite.mallet)
            .resizable()
            .frame(width: size, height: size)
            .keyframeAnimator(initialValue: rest, trigger: swing) { content, angle in
                content.rotationEffect(.degrees(angle), anchor: Sprite.malletGrip)
            } keyframes: { _ in
                KeyframeTrack {
                    if swing.calledOff {
                        // Pulled back mid-swing: up to rest, without a sound.
                        SpringKeyframe(rest, duration: 0.35, spring: .smooth)
                    } else {
                        // A small lift that eases to a stop, the swing that
                        // gathers speed into the wood, then the rebound.
                        LinearKeyframe(quick ? hit : rest + 7, duration: quick ? Fish.quickImpactDelay / 2 : Fish.liftDuration,
                                       timingCurve: .easeOut)
                        LinearKeyframe(hit, duration: quick ? Fish.quickImpactDelay / 2 : Fish.impactDelay - Fish.liftDuration,
                                       timingCurve: .easeIn)
                        if swing.lingers {
                            // 压槌: rest on the wood, then lift without a bounce.
                            // A new swing can interrupt this quiet at any time.
                            LinearKeyframe(hit, duration: 0.42)
                            LinearKeyframe(rest, duration: 0.85, timingCurve: .easeInOut)
                        } else {
                            SpringKeyframe(rest, duration: 0.5, spring: rebound)
                        }
                    }
                }
            }
            .position(x: grip.x + (0.5 - Sprite.malletGrip.x) * size,
                      y: grip.y + (0.5 - Sprite.malletGrip.y) * size)
            .allowsHitTesting(false)
    }

    /// A neon burst just under the mallet head where it meets the figure.
    /// Like the sound, it follows the quiet before the knock: a rushed knock
    /// flashes small and dim, one after a long quiet opens fully.
    private var impact: some View {
        let size = side * 0.26
        let headRadius = side * Sprite.malletSize * 0.13
        let bloom = fish.bloom
        return Image(nsImage: pack.impact ?? Sprite.impact)
            .resizable()
            .keyframeAnimator(initialValue: Flash(), trigger: fish.impacts) { content, v in
                // Grow the drawing bounds with the pulse, not just its pixels.
                let diameter = size * v.scale * (0.45 + 0.55 * bloom)
                content.frame(width: diameter, height: diameter)
                    .opacity(v.opacity * (0.5 + 0.5 * bloom))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(0.4, duration: 0.01)
                    // Start the bloom at rest: inheriting the fast reset's
                    // velocity on repeated knocks sends its size below zero.
                    CubicKeyframe(1.15, duration: 0.3, startVelocity: 0, endVelocity: 0)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1.0, duration: 0.01)
                    LinearKeyframe(1.0, duration: 0.08)
                    CubicKeyframe(0.0, duration: 0.25)
                }
            }
            .blendMode(pack.impact == nil ? .screen : .normal)
            .position(x: pack.strike.x * side, y: pack.strike.y * side + headRadius)
            .allowsHitTesting(false)
    }
}

/// A point along a frame sequence: whole positions show one frame, and in
/// between the next frame dissolves in over the current one.
private struct FrameBlend: View {
    let frames: [NSImage]
    let position: Double

    var body: some View {
        let p = min(max(position, 0), Double(frames.count - 1))
        let i = Int(p)
        ZStack {
            Image(nsImage: frames[i]).resizable()
            if i + 1 < frames.count {
                Image(nsImage: frames[i + 1]).resizable().opacity(p - Double(i))
            }
        }
    }
}

private struct Flash {
    var scale = 0.3
    var opacity = 0.0
}
