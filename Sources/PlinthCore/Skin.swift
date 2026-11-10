import Foundation

/// A skin: a folder of square sprite frames (`idle.png`, and optionally
/// `blink`, `hit`, `mallet.png`, `impact.png`) plus `skin.json` for its name,
/// strike point, voice and glow, or a single image as an idle-only skin.
///
/// This reads which files a skin has and what its `skin.json` says, and
/// decodes the images with `image`; `SkinPack` decodes them as the platform's.
///
/// docs/SKINS.md specifies the format and how it is drawn and animated. When
/// this loader or `SpriteFish` changes what a skin can contain or how it looks,
/// update that document (and docs/SKINS.zh-Hans.md) with it.
///
/// The wooden fishes have no blink or hit frame on purpose: a fish never
/// closes its eyes (鱼昼夜常醒), not even when struck.
public struct Skin<Image> {
    public var name: String?
    public var idle: Image
    public var blink: [Image]
    public var hit: [Image]
    public var mallet: Image?
    public var impact: Image?
    /// A `KnockSynth` voice. Nil is the wooden fish.
    public var voice: String?
    public var strike: CGPoint
    /// How far above its strike the mallet rests, in degrees around the grip.
    /// A figure struck on its face, under a crossbar, wants it higher.
    public var raise: Double
    /// The colour of the pedestal's neon, if it has one. The censer beside
    /// the fish catches its light.
    public var glow: SkinGlow?

    /// Where the mallet lands, and how far above it the mallet rests, unless
    /// the skin says otherwise.
    public static var defaultStrike: CGPoint { CGPoint(x: 0.6, y: 0.3) }
    public static var defaultRaise: Double { 25 }

    public init(name: String? = nil, idle: Image, blink: [Image] = [], hit: [Image] = [],
                mallet: Image? = nil, impact: Image? = nil, voice: String? = nil,
                strike: CGPoint = defaultStrike, raise: Double = defaultRaise, glow: SkinGlow? = nil) {
        self.name = name
        self.idle = idle
        self.blink = blink
        self.hit = hit
        self.mallet = mallet
        self.impact = impact
        self.voice = voice
        self.strike = strike
        self.raise = raise
        self.glow = glow
    }

    /// The skin at `url`, decoding each frame with `image`, which gives nil
    /// for a file that is missing or isn't an image. Its name is the one
    /// `skin.json` gives for `language`, the one the app is showing, if it
    /// gives one.
    public static func load(_ url: URL?, language: String? = Bundle.main.preferredLocalizations.first,
                            image: (URL) -> Image?) -> Skin? {
        guard let url else { return nil }
        if let single = image(url) { return Skin(idle: single) }
        func frame(_ name: String) -> Image? { image(url.appending(path: "\(name).png")) }
        func frames(_ name: String) -> [Image] {
            if let single = frame(name) { return [single] }
            // name-1, name-2, … up to the first that is missing or isn't an image.
            var all: [Image] = []
            while let next = frame("\(name)-\(all.count + 1)") { all.append(next) }
            return all
        }
        guard let idle = frame("idle") else { return nil }
        var skin = Skin(idle: idle, blink: frames("blink"), hit: frames("hit"),
                        mallet: frame("mallet"), impact: frame("impact"))
        if let data = try? Data(contentsOf: url.appending(path: "skin.json")),
           let meta = try? JSONDecoder().decode(SkinMeta.self, from: data) {
            skin.name = language.flatMap { meta.names?[$0] } ?? meta.name
            skin.voice = meta.voice
            if let s = meta.strike, s.count == 2 { skin.strike = CGPoint(x: s[0], y: s[1]) }
            skin.glow = meta.glow.flatMap(SkinGlow.init(hex:))
            if let r = meta.raise { skin.raise = min(max(r, 0), 80) }
        }
        return skin
    }
}

/// What `skin.json` may say.
private struct SkinMeta: Decodable {
    var name: String?
    /// The name in other languages, keyed as an app's localizations are: "zh-Hans".
    var names: [String: String]?
    var strike: [Double]?
    var voice: String?
    var glow: String?
    var raise: Double?
}

/// A skin's glow, from 0 to 1 in each of red, green and blue.
public struct SkinGlow: Equatable {
    public var red, green, blue: Double

    /// A colour written as `#RRGGBB`.
    public init?(hex: String) {
        guard hex.count == 7, hex.first == "#", let v = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        red = Double(v >> 16 & 0xFF) / 255
        green = Double(v >> 8 & 0xFF) / 255
        blue = Double(v & 0xFF) / 255
    }
}

/// What a file is on disk, cheap to read: enough to tell when a skin has
/// changed without decoding its images. The status-change time moves on
/// every write, rename or replacement, even one that keeps the old
/// modification date, as a Finder copy does.
public struct FileStamp: Equatable {
    var name: String
    var inode: UInt64
    var size: Int64
    var changed: timespec

    public static func == (a: FileStamp, b: FileStamp) -> Bool {
        a.name == b.name && a.inode == b.inode && a.size == b.size
            && a.changed.tv_sec == b.changed.tv_sec && a.changed.tv_nsec == b.changed.tv_nsec
    }

    /// The file itself, then, for a folder skin, each file in it.
    public static func of(_ url: URL) -> [FileStamp] {
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
