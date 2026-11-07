import CoreHaptics

/// The knock in the hand, made from the numbers the knock's sound is made
/// from: a tap as the mallet meets the wood, harder for a harder blow and
/// sharper off the strike point, where the shell speaks more than the hollow;
/// then the hollow's low hum, longer after a long quiet, as the knock rings
/// longer. Phones without a Taptic Engine, and the Simulator, feel nothing.
final class KnockHaptics {
    private let engine: CHHapticEngine?

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine = try? CHHapticEngine() else {
            engine = nil
            return
        }
        engine.playsHapticsOnly = true
        // It sleeps between knocks, and wakes for the next.
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak engine] in try? engine?.start() }
        self.engine = engine
    }

    /// Play one knock as the mallet lands, with its `force` (0 to 1), `place`
    /// (-1 to 1 off the strike point), and `bloom` (0 to 1).
    func play(force: Float, place: Float, bloom: Double) {
        guard let engine, let pattern = try? Self.pattern(force: force, place: place, bloom: bloom) else { return }
        try? engine.start()
        try? engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
    }

    static func pattern(force: Float, place: Float, bloom: Double) throws -> CHHapticPattern {
        let edge = min(abs(place), 1)
        let tap = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3 + 0.7 * force),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3 + 0.5 * edge),
        ], relativeTime: 0)
        // Off the strike point the hollow says less.
        let ring = 0.05 + 0.15 * bloom
        let hollow = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4 * force * (1 - 0.6 * edge)),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
        ], relativeTime: 0.005, duration: ring)
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 1),
            CHHapticParameterCurve.ControlPoint(relativeTime: ring, value: 0),
        ], relativeTime: 0.005)
        return try CHHapticPattern(events: [tap, hollow], parameterCurves: [fade])
    }
}
