import Foundation

/// How auto-knock spaces its knocks around the chosen interval.
public enum Rhythm: String, CaseIterable, Identifiable {
    case steady, quickening, natural
    public var id: Self { self }
    public var title: String {
        switch self {
        case .steady: String(localized: "Steady")
        case .quickening: String(localized: "Quickening")
        case .natural: String(localized: "Natural")
        }
    }

    /// One line on what this rhythm sounds like, for Settings.
    public var about: String {
        switch self {
        case .steady: String(localized: "Steady: the same quiet between every knock.")
        case .quickening: String(localized: "Quickening (起板): three slow, firm knocks, then faster and lighter; a pause, a firm closing knock, then a rest.")
        case .natural: String(localized: "Natural: each gap runs a little long or short, like a hand keeping time.")
        }
    }

    /// The quiet before auto-knock's knock number `n`, counting from 0.
    public func gap(before n: Int, interval: Double) -> Double {
        switch self {
        case .steady:
            return interval
        case .natural:
            // A hand keeping time: each gap a little long or short, about 0.7 to 1.4 times.
            return interval * exp(.random(in: -0.35...0.35))
        case .quickening:
            // 起板: three slow knocks, then a lighter roll. Wait half a beat
            // before the closing knock, and rest before the next round.
            let k = n % 15
            if k == 0 { return n == 0 ? interval : interval * 5 }
            if k <= 2 { return interval * 2.5 }
            if k == 14 { return max(interval * 0.25, 0.15) + interval * 0.5 }
            return max(interval * 2.5 * pow(0.1, Double(k - 2) / 11), 0.15)
        }
    }

    /// A quickening hand grows lighter, not louder, as it hurries. Other
    /// rhythms leave the touch alone. The fifteenth knock settles the round.
    public func stroke(at n: Int) -> (force: Float?, closing: Bool) {
        guard self == .quickening else { return (nil, false) }
        let k = n % 15
        if k == 14 { return (0.78, true) }
        if k <= 2 { return (0.68 - 0.02 * Float(k), false) }
        return (0.58 - 0.30 * Float(k - 3) / 10, false)
    }
}

/// An incense period, not a stopwatch. Each stick burns a little differently.
public enum IncenseLength: Int, CaseIterable, Identifiable {
    case half = 25, one = 45, long = 60
    public var id: Self { self }
    public var title: String {
        switch self {
        case .half: String(localized: "Half a stick")
        case .one: String(localized: "One stick")
        case .long: String(localized: "Long incense")
        }
    }
}

/// One swing of the mallet. `quick` is the short swing for a typed key;
/// `calledOff` takes a swing still in the air back up without landing;
/// `lingers` rests on the wood before lifting slowly (压槌). One that `holds`
/// lands and stays on the wood, as after a call no one answered, and the
/// swing after it `rises` from there.
public struct Swing: Equatable {
    /// Time from the start of the swing until the mallet meets the wood, and
    /// how much of it the small lift before the swing takes.
    public static let impactDelay = 0.13
    public static let liftDuration = 0.05
    /// A typed key gets a short, quick swing, so the knock keeps up with the hand.
    public static let quickImpactDelay = 0.03

    public var serial = 0
    public var quick = false
    public var calledOff = false
    public var lingers = false
    public var holds = false
    public var rises = false

    public init(serial: Int = 0, quick: Bool = false, calledOff: Bool = false, lingers: Bool = false,
                holds: Bool = false, rises: Bool = false) {
        self.serial = serial
        self.quick = quick
        self.calledOff = calledOff
        self.lingers = lingers
        self.holds = holds
        self.rises = rises
    }

    /// How hard the mallet lands when nothing tells how firmly the hand
    /// pressed, as with a mouse, a finger on glass, or auto-knock: about as
    /// hard each time, and lighter after a short quiet. `rested` is the
    /// bloom of that quiet.
    public static func force(rested: Float) -> Float {
        (0.58 + .random(in: -0.07...0.07)) * (0.85 + 0.15 * rested)
    }

    /// Where the mallet lands, from -1 to 1 off the strike point: from `x`
    /// across the figure, 0 at its left edge and 1 at its right, or near the
    /// strike point when nothing says where.
    public static func place(at x: Double?, strike: Double) -> Float {
        // A quarter of the figure's width off the strike point is the edge.
        let place = x.map { Float(($0 - strike) / 0.25) } ?? .random(in: -0.2...0.2)
        return min(max(place, -1), 1)
    }
}

/// A stick of incense, lit at `lit`, that burns for `duration` seconds.
public struct Incense: Equatable {
    public let lit: Date
    public let duration: TimeInterval

    public init(lit: Date, duration: TimeInterval) {
        self.lit = lit
        self.duration = duration
    }

    public func burnt(at date: Date) -> Double {
        min(max(date.timeIntervalSince(lit) / duration, 0), 1)
    }
}
