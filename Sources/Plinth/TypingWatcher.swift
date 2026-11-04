import AppKit
import CoreGraphics

/// Notices key presses in any app, for "Knock as you type" and the bell,
/// without any special permission. It never sees which key: it only asks macOS
/// how long ago a key last went down or came up (the counters idle timers use).
@MainActor
final class TypingWatcher {
    var onPress: () -> Void = {}

    private var timer: DispatchSourceTimer?
    /// Whether the timer asks often enough to knock with each key. For the
    /// bell alone it asks about once a second, so the Mac is seldom woken for it.
    private var keyByKey = false
    private var lastDown = 0.0
    private var lastPress = 0.0
    /// When the current run of key presses with no key coming up began.
    private var heldSince = 0.0

    /// Start watching, or go on at a new pace. With `keyByKey`, each press is
    /// noticed as it happens; without it, within about a second.
    func start(keyByKey: Bool) {
        if let timer {
            guard keyByKey != self.keyByKey else { return }
            timer.cancel()
        } else {
            lastDown = Self.lastEvent(.keyDown)
            heldSince = lastDown
        }
        self.keyByKey = keyByKey
        let timer = DispatchSource.makeTimerSource(queue: .main)
        if keyByKey {
            timer.schedule(deadline: .now(), repeating: .milliseconds(25), leeway: .milliseconds(5))
        } else {
            timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(500))
        }
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.check() }
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// When the keyboard or mouse itself last sent an event of `type`, on the uptime clock.
    static func lastEvent(_ type: CGEventType) -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
            - CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: type)
    }

    private func check() {
        let down = Self.lastEvent(.keyDown)
        guard down > lastDown + 0.001 else { return }
        let fresh = Self.lastEvent(.keyUp) > lastDown
        if fresh { heldSince = down }
        lastDown = down
        // A held key repeats with no key coming up in between, so only its
        // first press counts. Keys rolled over quickly while typing still do.
        guard fresh || down - heldSince < NSEvent.keyRepeatDelay * 0.8 else { return }
        // Keys mashed together count once.
        guard down - lastPress > 0.05 else { return }
        lastPress = down
        onPress()
    }
}
