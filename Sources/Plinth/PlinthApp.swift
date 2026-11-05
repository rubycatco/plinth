import SwiftUI

@main
struct PlinthApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            FishMenu().environment(Fish.shared)
        } label: {
            MenuBarIcon().environment(Fish.shared)
        }
        Settings {
            SettingsView().environment(Fish.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    /// A `plinth://knock` or `plinth://call` that launched Plinth comes before
    /// the fish is on screen. It waits for the fish, so the mallet is seen to fall.
    private var atLaunch: [() -> Void] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let fish = Fish.shared
        // Start at the real size: a borderless panel restores only its saved
        // origin, and layoutPanel re-centres on the current width.
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: panelSize()), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let host = NSHostingView(rootView: FishView().environment(fish))
        host.sizingOptions = []
        panel.contentView = host
        PanelMover.panel = panel

        if !panel.setFrameUsingName("PlinthPanel"), let screen = NSScreen.main {
            let v = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: v.maxX - 300, y: v.minY + 40))
        }
        panel.setFrameAutosaveName("PlinthPanel")
        fish.onWindowChange = { [weak self] in self?.layoutPanel() }
        // The knock comes from where the fish sits, and follows it when dragged.
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.placeSound() }
        }
        layoutPanel()
        keepOnScreen(animated: false)
        // A fish let go mostly past a screen's edge slides back into view, and
        // one left on a display that is gone comes to one that is there.
        PanelMover.onDrop = { [weak self] in self?.keepOnScreen(animated: true) }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.keepOnScreen(animated: false)
                // The displays may stand differently around you now.
                self?.placeSound()
            }
        }
        placeSound()
        Updates.shared.start()
        if !atLaunch.isEmpty {
            let waiting = atLaunch
            atLaunch = []
            DispatchQueue.main.async { waiting.forEach { $0() } }
        }
    }

    /// The knock comes from where the fish sits among the displays, as they
    /// are arranged in System Settings, measured from the middle of the main
    /// display (the one with the menu bar). Fish leaves this position behind
    /// in unseen mode, blending the knock into the surrounding hall instead.
    private func placeSound() {
        guard let main = NSScreen.screens.first?.frame else {
            return Fish.shared.heard(across: 0, up: 0)
        }
        Fish.shared.heard(across: (panel.frame.midX - main.midX) / main.width,
                          up: (panel.frame.midY - main.midY) / main.height)
    }

    /// `plinth://knock` knocks once, so scripts and other apps can knock, and
    /// `plinth://call` calls you back, as when a coding agent is done.
    /// Files opened with Plinth, such as `.plinthskin`, are installed as skins.
    func application(_ application: NSApplication, open urls: [URL]) {
        Fish.shared.install(urls.filter(\.isFileURL))
        for url in urls where url.scheme == "plinth" {
            switch url.host() {
            case "knock": whenOnScreen { Fish.shared.knock(byHand: false) }
            case "call": whenOnScreen { Fish.shared.call() }
            default: break
            }
        }
    }

    private func whenOnScreen(_ action: @escaping () -> Void) {
        if panel == nil { atLaunch.append(action) } else { action() }
    }

    private func panelSize() -> NSSize {
        let side = Fish.shared.size.side
        return NSSize(width: max(side, 250), height: side + 64)
    }

    /// The part of the panel the fish itself fills: its top square, under
    /// which the caption hangs.
    private func fishFrame(_ frame: NSRect) -> NSRect {
        let side = Fish.shared.size.side
        return NSRect(x: frame.midX - side / 2, y: frame.maxY - side, width: side, height: side)
    }

    /// Keep at least a third of the fish on some screen. Past that, bring it
    /// just inside the nearest screen's visible area.
    private func keepOnScreen(animated: Bool) {
        let fish = fishFrame(panel.frame)
        let screens = NSScreen.screens
        let shown = screens.map { $0.frame.intersection(fish) }.map { $0.isNull ? 0 : $0.width * $0.height }.max() ?? 0
        guard shown < fish.width * fish.height / 3 else { return }
        let nearest = screens.min { a, b in
            hypot(a.visibleFrame.midX - fish.midX, a.visibleFrame.midY - fish.midY)
                < hypot(b.visibleFrame.midX - fish.midX, b.visibleFrame.midY - fish.midY)
        }
        guard let area = nearest?.visibleFrame else { return }
        let x = min(max(fish.minX, area.minX), area.maxX - fish.width)
        let y = min(max(fish.minY, area.minY), area.maxY - fish.height)
        var frame = panel.frame
        frame.origin.x += x - fish.minX
        frame.origin.y += y - fish.minY
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    /// Size the panel for the fish and keep its bottom centre where it was.
    private func layoutPanel() {
        let size = panelSize()
        let old = panel.frame
        panel.setFrame(NSRect(x: old.midX - size.width / 2, y: old.minY,
                              width: size.width, height: size.height), display: true)
        panel.level = switch Fish.shared.placement {
        case .floating, .unseen: .floating
        case .desktop: NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        }
        if Fish.shared.placement == .unseen { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
        placeSound()
    }
}
