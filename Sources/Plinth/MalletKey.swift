import AppKit
import Carbon.HIToolbox

/// One key, or a key and its modifiers, that knocks by hand from any app: a
/// key on a one-key keypad, a foot pedal, or a Stream Deck button. It is a
/// system hot key, so it needs no permission, and works in the sandbox.
struct MalletKey: Equatable {
    var code: UInt32
    /// Carbon's modifier bits, as `RegisterEventHotKey` takes them.
    var modifiers: UInt32
    /// What the key is called, as the keyboard named it when it was recorded.
    var title: String

    private static let functionKeys: [Int: Int] = [
        kVK_F1: 1, kVK_F2: 2, kVK_F3: 3, kVK_F4: 4, kVK_F5: 5, kVK_F6: 6, kVK_F7: 7, kVK_F8: 8,
        kVK_F9: 9, kVK_F10: 10, kVK_F11: 11, kVK_F12: 12, kVK_F13: 13, kVK_F14: 14, kVK_F15: 15,
        kVK_F16: 16, kVK_F17: 17, kVK_F18: 18, kVK_F19: 19, kVK_F20: 20,
    ]
    private static let named: [Int: String] = [
        kVK_Space: String(localized: "Space (key)", defaultValue: "Space"), kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_Escape: "⎋", kVK_ANSI_KeypadEnter: "⌤",
    ]

    /// The key pressed in `event`, if it can be the mallet. An F-key can stand
    /// alone, as a pedal or a one-key keypad usually sends. Any other key needs
    /// ⌘ or ⌃, or it would no longer type, and one more modifier besides: the
    /// mallet key is taken from every app, and ⌘ or ⌃ alone would take a
    /// shortcut used every day, such as ⌘W or ⌃C, perhaps pressed out of habit
    /// while the key is being recorded.
    init?(_ event: NSEvent) {
        let code = Int(event.keyCode)
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let function = Self.functionKeys[code]
        let held = [NSEvent.ModifierFlags.command, .control, .option, .shift].filter(flags.contains).count
        guard function != nil || (!flags.isDisjoint(with: [.command, .control]) && held >= 2) else { return nil }
        // Named as on the key, not as Shift or Option would type it: ⇧⌘2, not ⇧⌘@.
        let key = function.map { "F\($0)" } ?? Self.named[code]
            ?? event.characters(byApplyingModifiers: []).map { $0.uppercased() } ?? ""
        guard !key.isEmpty, !key.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else {
            return nil
        }
        var modifiers: UInt32 = 0
        var symbols = ""
        for (flag, bit, symbol) in [(NSEvent.ModifierFlags.control, controlKey, "⌃"), (.option, optionKey, "⌥"),
                                    (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")] where flags.contains(flag) {
            modifiers |= UInt32(bit)
            symbols += symbol
        }
        self.init(code: UInt32(code), modifiers: modifiers, title: symbols + key)
    }

    init(code: UInt32, modifiers: UInt32, title: String) {
        self.code = code
        self.modifiers = modifiers
        self.title = title
    }

    init?(stored: [String: Any]?) {
        guard let stored, let code = stored["code"] as? Int, let modifiers = stored["modifiers"] as? Int,
              let title = stored["title"] as? String else { return nil }
        self.init(code: UInt32(code), modifiers: UInt32(modifiers), title: title)
    }

    var stored: [String: Any] { ["code": Int(code), "modifiers": Int(modifiers), "title": title] }
}

/// Holds the mallet key with macOS, and hears it go down.
@MainActor
final class MalletKeyWatcher {
    var onPress: () -> Void = {}

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    /// A held key repeats; only the press that went down knocks.
    private var down = false
    private static weak var current: MalletKeyWatcher?

    /// Hold `key`, letting go of any other. False if another app holds it already.
    func watch(_ key: MalletKey?) -> Bool {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        down = false
        guard let key else { return true }
        listen()
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: 0x504C_4E54, id: 1) // 'PLNT'
        guard RegisterEventHotKey(key.code, key.modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr else {
            return false
        }
        hotKey = ref
        return true
    }

    private func listen() {
        guard handler == nil else { return }
        Self.current = self
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        // Hot key events come on the main thread.
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            MainActor.assumeIsolated { MalletKeyWatcher.current?.heard(pressed: pressed) }
            return noErr
        }, types.count, &types, nil, &handler)
    }

    private func heard(pressed: Bool) {
        defer { down = pressed }
        if pressed && !down { onPress() }
    }
}
