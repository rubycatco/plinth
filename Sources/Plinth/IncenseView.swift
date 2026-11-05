import PlinthCore
import SwiftUI

/// A stick in a plain ash bowl beside the fish. A small flame takes as it is
/// lit and goes out; then the ember glows under a growing cap of ash, which
/// now and then breaks off into the censer, and smoke rises straight before
/// it starts to curl. A knock stirs the air. When the stick is spent the ember
/// dies and the last smoke drifts up and away. It shows no numbers.
struct IncenseView: View {
    let incense: Incense
    let side: CGFloat
    @Environment(Fish.self) private var fish
    /// When the latest knock stirred the air.
    @State private var stir = Date.distantPast

    /// How far left of the fish's frame the drawing starts, so smoke drifting
    /// that way is not cut off.
    static let lead = 0.1

    private static let censer = Bundle.main.url(forResource: "censer", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:)) ?? NSImage()

    var body: some View {
        // Slow smoke needs no more than this, and it keeps the stick cheap.
        TimelineView(.periodic(from: .now, by: 1.0 / 24)) { context in
            Canvas { gc, _ in
                draw(in: &gc, now: context.date)
            }
        }
        .frame(width: side * 0.42, height: side)
        .allowsHitTesting(false)
        .onChange(of: fish.impacts) { stir = .now }
        .accessibilityLabel("Incense")
    }

    // MARK: - Drawing

    private func draw(in gc: inout GraphicsContext, now: Date) {
        let age = now.timeIntervalSince(incense.lit)
        let duration = incense.duration
        let clock = now.timeIntervalSinceReferenceDate
        let seed = incense.lit.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 997)
        let sinceStir = now.timeIntervalSince(stir)
        let gust = sinceStir >= 0 ? exp(-sinceStir / 1.4) : 0

        // A low, plain bowl beside the pedestal, level with its left corner.
        let cw = side * 0.16, ch = cw * 170 / 280
        let censer = CGRect(x: side * (Self.lead + 0.135) - cw / 2, y: side * 0.925 - ch, width: cw, height: ch)
        let plant = CGPoint(x: censer.minX + cw * 0.502, y: censer.minY + ch * 0.27)
        let bowl = Image(nsImage: Self.censer)
        // A shade dimmer and duller than the fish, so it stays in the background.
        var quiet = gc
        quiet.addFilter(.saturation(0.8))
        quiet.addFilter(.brightness(-0.04))
        quiet.draw(bowl, in: censer)
        // The pedestal's neon falls on the side of the bowl facing it: the
        // bowl, tinted by the light, is added again, so its lit glaze catches
        // it and the shadows stay dark.
        if let glow = fish.pack.glow {
            var lit = gc
            lit.clipToLayer { mask in
                mask.fill(Path(censer), with: .linearGradient(
                    Gradient(colors: [.black.opacity(0.7), .black.opacity(0.25), .clear]),
                    startPoint: CGPoint(x: censer.maxX, y: censer.maxY - ch * 0.2),
                    endPoint: CGPoint(x: censer.minX + cw * 0.4, y: censer.minY + ch * 0.35)))
            }
            lit.addFilter(.colorMultiply(glow))
            lit.blendMode = .plusLighter
            lit.draw(bowl, in: censer)
        }

        // The stick: a red bamboo stem with a coat of incense above it. Only
        // the coat burns, so a spent stick leaves the stem standing.
        let stemLength = side * 0.03, coatLength = side * 0.23
        let coatWidth = max(side * 0.011, 1.8), stemWidth = coatWidth * 0.55
        let stemTop = plant.y - stemLength
        let burntLength = coatLength * incense.burnt(at: now)
        let front = stemTop - (coatLength - burntLength)
        let x = plant.x

        // Ash that has broken off lies on the bed around the stick.
        let ash = AshBreaks(seed: seed, maxLength: side * 0.032, burnt: burntLength)
        for k in 0..<ash.fallen {
            let dx = (hash(seed, k, 1) - 0.5) * cw * 0.3, dy = (hash(seed, k, 2) - 0.3) * ch * 0.06
            let r = side * (0.004 + 0.003 * hash(seed, k, 3))
            gc.fill(Path(ellipseIn: CGRect(x: x + dx - r * 1.4, y: plant.y + dy - r * 0.5, width: r * 2.8, height: r)),
                    with: .color(Color(white: 0.34 + 0.1 * hash(seed, k, 4)).opacity(0.6)))
        }

        gc.fill(Path(CGRect(x: x - stemWidth / 2, y: stemTop, width: stemWidth, height: plant.y - stemTop)),
                with: rod((0.52, 0.12, 0.1), x: x, width: stemWidth))
        if front < stemTop {
            gc.fill(Path(roundedRect: CGRect(x: x - coatWidth / 2, y: front, width: coatWidth, height: stemTop - front + 0.5),
                         cornerRadius: coatWidth * 0.3),
                    with: rod((0.38, 0.24, 0.16), x: x, width: coatWidth))
        }

        // The ember: bright as it catches, breathing while it burns, dying
        // once the coat is gone.
        let spent = age - duration
        let catching = 1 + 0.5 * (1 - smoothstep(0.8, 3.5, age))
        let dying = spent > 0 ? 1 - smoothstep(0, 3, spent) : 1
        let breath = 0.86 + 0.09 * sin(clock * 2.1 + seed) + 0.05 * sin(clock * 5.3 + seed * 2)
        let heat = catching * dying * (breath + 0.35 * exp(-max(sinceStir, 0) / 0.5))

        // Below the ember the coat chars, and reddens while it burns.
        if front < stemTop {
            let char = CGRect(x: x - coatWidth / 2, y: front, width: coatWidth, height: min(coatWidth * 1.6, stemTop - front))
            gc.fill(Path(char), with: .linearGradient(
                Gradient(colors: [Color(white: 0.12), Color(white: 0.12).opacity(0)]),
                startPoint: CGPoint(x: x, y: char.minY), endPoint: CGPoint(x: x, y: char.maxY)))
        }
        if heat > 0.01 {
            let char = CGRect(x: x - coatWidth / 2, y: front, width: coatWidth, height: coatWidth * 2.2)
            gc.fill(Path(char), with: .linearGradient(
                Gradient(stops: [.init(color: Color(red: 1, green: 0.42, blue: 0.12).opacity(min(heat, 1)), location: 0),
                                 .init(color: Color(red: 0.55, green: 0.08, blue: 0.04).opacity(0.8 * min(heat, 1)), location: 0.35),
                                 .init(color: Color(red: 0.2, green: 0.08, blue: 0.05).opacity(0), location: 1)]),
                startPoint: CGPoint(x: x, y: char.minY), endPoint: CGPoint(x: x, y: char.maxY)))
        }

        // The ash cap leans a little more the longer it grows.
        let lean = (hash(seed, 0, 9) < 0.5 ? -1.0 : 1.0) * (0.04 + 0.12 * ash.length / (side * 0.032))
        let ashTop = CGPoint(x: x + sin(lean) * ash.length, y: front - cos(lean) * ash.length)
        if ash.length > 0.3 {
            var cap = gc
            cap.translateBy(x: x, y: front)
            cap.rotate(by: .radians(lean))
            let w = coatWidth * 1.08
            cap.fill(Path(roundedRect: CGRect(x: -w / 2, y: -ash.length, width: w, height: ash.length + 0.5), cornerRadius: w * 0.45),
                     with: .linearGradient(
                        Gradient(stops: [.init(color: Color(white: 0.56), location: 0),
                                         .init(color: Color(white: 0.47), location: 0.6),
                                         .init(color: Color(white: 0.24), location: 1)]),
                        startPoint: CGPoint(x: 0, y: -ash.length), endPoint: .zero))
            // Fine rings where the ash has cracked as it cooled.
            var ring = -coatWidth * 0.9
            while ring > -ash.length + coatWidth * 0.4 {
                cap.fill(Path(CGRect(x: -w / 2, y: ring, width: w, height: max(side * 0.0015, 0.5))),
                         with: .color(Color(white: 0.3).opacity(0.45)))
                ring -= coatWidth * 1.1
            }
        }

        // A flake of ash just broken off, falling into the bed.
        if let drop = ash.lastBreak {
            let fell = age - drop.at * duration / coatLength
            let fall = 0.55
            if fell >= 0, fell < fall {
                let p = fell / fall
                let y = front - drop.length + (plant.y - (front - drop.length)) * p * p
                var flake = gc
                flake.opacity = 1 - smoothstep(0.75, 1, p)
                flake.translateBy(x: x + (hash(seed, drop.index, 5) - 0.5) * cw * 0.2 * p, y: y)
                flake.rotate(by: .radians(lean + p * p * 1.4 * (hash(seed, drop.index, 6) - 0.5)))
                flake.fill(Path(roundedRect: CGRect(x: -coatWidth / 2, y: 0, width: coatWidth, height: drop.length),
                                cornerRadius: coatWidth * 0.45), with: .color(Color(white: 0.5)))
            }
        }

        // The ember's glow, under and around the ash.
        if heat > 0.01 {
            var glow = gc
            glow.blendMode = .plusLighter
            let r = side * 0.03 * heat
            glow.fill(Path(ellipseIn: CGRect(x: x - r, y: front - r, width: r * 2, height: r * 2)),
                      with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.5, blue: 0.18).opacity(0.75 * min(heat, 1.2)),
                                                              Color(red: 1, green: 0.3, blue: 0.08).opacity(0.25 * min(heat, 1)),
                                                              .clear]),
                                            center: CGPoint(x: x, y: front), startRadius: 0, endRadius: r))
            let core = coatWidth * 0.55
            glow.fill(Path(ellipseIn: CGRect(x: x - core, y: front - core * 0.6, width: core * 2, height: core * 1.2)),
                      with: .color(Color(red: 1, green: 0.62 + 0.25 * min(heat - 0.8, 0.4), blue: 0.3).opacity(min(heat, 1))))
        }

        drawSmoke(in: &gc, from: ashTop, age: age, duration: duration, clock: clock, seed: seed,
                  stir: sinceStir, gust: gust)
        drawFlame(in: &gc, at: CGPoint(x: x, y: front), age: age, gust: gust, width: coatWidth)
    }

    /// The flame that takes when the stick is lit, and goes out on its own.
    private func drawFlame(in gc: inout GraphicsContext, at tip: CGPoint, age: Double, gust: Double, width: CGFloat) {
        let size = 1 - smoothstep(0.7, 1.6, age)
        guard size > 0 else { return }
        let flicker = 1 + 0.12 * sin(age * 31) + 0.08 * sin(age * 17 + 1)
        let h = side * 0.05 * size * flicker
        let w = max(width * 1.5, side * 0.012) * (0.6 + 0.4 * size)
        let sway = side * 0.008 * (sin(age * 9) + 2 * gust)
        let top = CGPoint(x: tip.x + sway, y: tip.y - h)
        var flame = Path()
        flame.move(to: CGPoint(x: tip.x, y: tip.y + w * 0.4))
        flame.addCurve(to: top, control1: CGPoint(x: tip.x - w, y: tip.y), control2: CGPoint(x: tip.x - w * 0.2, y: tip.y - h * 0.6))
        flame.addCurve(to: CGPoint(x: tip.x, y: tip.y + w * 0.4), control1: CGPoint(x: tip.x + w * 0.2 + sway * 0.3, y: tip.y - h * 0.6),
                       control2: CGPoint(x: tip.x + w, y: tip.y))
        var lit = gc
        lit.blendMode = .plusLighter
        lit.addFilter(.blur(radius: max(side * 0.0025, 0.4)))
        lit.fill(flame, with: .linearGradient(
            Gradient(stops: [.init(color: Color(red: 1, green: 0.97, blue: 0.85), location: 0),
                             .init(color: Color(red: 1, green: 0.72, blue: 0.25), location: 0.45),
                             .init(color: Color(red: 1, green: 0.35, blue: 0.08).opacity(0.6), location: 1)]),
            startPoint: CGPoint(x: tip.x, y: tip.y), endPoint: top))
    }

    /// Smoke as a stream of puffs leaving the ember at a steady pace. Each
    /// carries the sway it was born with, so the curls rise with the smoke:
    /// straight just above the ember, then a slow waver, then strands that
    /// part and thin out. Puffs are only born while the stick burns.
    private func drawSmoke(in gc: inout GraphicsContext, from source: CGPoint, age: Double, duration: Double,
                           clock: Double, seed: Double, stir: Double, gust: Double) {
        let height = side * 0.38
        let speed = side * 0.075
        // Smoke starts once the flame is out, and stops when the coat is gone.
        let first = 1.4, last = duration
        let breeze = 0.6 * sin(clock * 0.11 + seed) + 0.4 * sin(clock * 0.043 + seed * 1.7)
        let steps = 40

        func point(_ s: Double, strand: Int) -> (CGPoint, born: Double) {
            let born = age - s * height / speed
            let laminar = smoothstep(0.1, 0.55, s)
            var dx = side * 0.038 * laminar * (1 + 0.8 * s) * sin(born * 0.9 + seed + s * 2.2)
            dx += side * 0.016 * laminar * sin(born * 2.3 + seed * 3 + s * 5)
            dx += side * 0.07 * pow(s, 1.6) * breeze
            // A knock pushes the air, and the whole column ripples with it.
            dx += side * 0.04 * gust * s * sin(s * 9 - stir * 4)
            if strand != 0 {
                let part = max(0, s - 0.35)
                dx += Double(strand) * side * 0.09 * part * (0.6 + 0.4 * sin(born * 0.7 + Double(strand) + seed))
            }
            return (CGPoint(x: source.x + dx, y: source.y - s * height), born)
        }

        var layer = gc
        layer.addFilter(.blur(radius: max(side * 0.004, 0.7)))
        var haze = gc
        haze.addFilter(.blur(radius: side * 0.014))
        let base = max(side * 0.006, 1)
        let tint = Color(red: 0.8, green: 0.82, blue: 0.88)

        for strand in [0, -1, 1] {
            let strength = strand == 0 ? 0.55 : 0.22
            var previous: (CGPoint, born: Double)?
            for i in 0...steps {
                let s = Double(i) / Double(steps)
                if strand != 0 && s < 0.35 { continue }
                let current = point(s, strand: strand)
                defer { previous = current }
                guard let previous, current.born >= first, current.born <= last,
                      previous.born >= first, previous.born <= last else { continue }
                // The puff right after the flame goes out is thicker.
                let puff = 1 + 0.6 * (1 - smoothstep(first, first + 2.5, current.born))
                let alpha = strength * puff * smoothstep(0, 0.06, s) * pow(1 - s, 1.4)
                var segment = Path()
                segment.move(to: previous.0)
                segment.addLine(to: current.0)
                let width = base * (1 + 4 * s) * (strand == 0 ? 1 : 0.7) * puff
                layer.stroke(segment, with: .color(tint.opacity(alpha)),
                             style: StrokeStyle(lineWidth: width, lineCap: .round))
                if strand == 0 {
                    haze.stroke(segment, with: .color(tint.opacity(alpha * 0.2)),
                                style: StrokeStyle(lineWidth: width * 4, lineCap: .round))
                }
            }
        }
    }

    /// A rod lit from the upper left: a soft highlight, darker toward the edges.
    private func rod(_ c: (Double, Double, Double), x: CGFloat, width: CGFloat) -> GraphicsContext.Shading {
        func tone(_ f: Double) -> Color { Color(red: min(c.0 * f, 1), green: min(c.1 * f, 1), blue: min(c.2 * f, 1)) }
        return .linearGradient(Gradient(stops: [.init(color: tone(0.65), location: 0),
                                                .init(color: tone(1.3), location: 0.32),
                                                .init(color: tone(1), location: 0.55),
                                                .init(color: tone(0.5), location: 1)]),
                               startPoint: CGPoint(x: x - width / 2, y: 0), endPoint: CGPoint(x: x + width / 2, y: 0))
    }
}

/// Where the ash breaks: every so often, at a slightly different length each
/// time, a piece of the cap falls. Worked out from how much has burnt, so it
/// needs no state.
private struct AshBreaks {
    /// How many pieces have fallen, and the cap still standing.
    var fallen = 0
    var length: CGFloat = 0
    var lastBreak: (index: Int, at: CGFloat, length: CGFloat)?

    init(seed: Double, maxLength: CGFloat, burnt: CGFloat) {
        var mark: CGFloat = 0
        while true {
            let piece = maxLength * (0.55 + 0.45 * hash(seed, fallen, 7))
            guard mark + piece <= burnt else { break }
            mark += piece
            lastBreak = (fallen, mark, piece * 0.9)
            fallen += 1
        }
        // Ash is a little shorter than the incense it was.
        length = (burnt - mark) * 0.9
    }
}

/// A steady pseudo-random number in 0..<1 for a stick, an index and a use.
private func hash(_ seed: Double, _ k: Int, _ salt: Int) -> Double {
    let v = sin(seed * 12.9898 + Double(k) * 78.233 + Double(salt) * 37.719) * 43758.5453
    return v - v.rounded(.down)
}

private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}
