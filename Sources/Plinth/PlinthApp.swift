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
        // The desktop widget's Knock button, from the widget's own process.
        DistributedNotificationCenter.default().addObserver(forName: .init("dev.rubycat.plinth.knock"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Fish.shared.knock(byHand: false) }
        }
        // The knock comes from where the fish sits, and follows it when dragged.
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.placeSound() }
        }
        layoutPanel()
        panel.orderFrontRegardless()
        placeSound()
        Updates.shared.start()
    }

    private func placeSound() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        Fish.shared.heard(at: (panel.frame.midX - screen.frame.minX) / screen.frame.width)
    }

    /// `plinth://knock` knocks once, so scripts and other apps can knock.
    /// Files opened with Plinth, such as `.plinthskin`, are installed as skins.
    func application(_ application: NSApplication, open urls: [URL]) {
        Fish.shared.install(urls.filter(\.isFileURL))
        for url in urls where url.scheme == "plinth" && url.host() == "knock" {
            Fish.shared.knock(byHand: false)
        }
    }

    private func panelSize() -> NSSize {
        let side = Fish.shared.size.side
        return NSSize(width: max(side, 250), height: side + 64)
    }

    /// Size the panel for the fish and keep its bottom centre where it was.
    private func layoutPanel() {
        let size = panelSize()
        let old = panel.frame
        panel.setFrame(NSRect(x: old.midX - size.width / 2, y: old.minY,
                              width: size.width, height: size.height), display: true)
        panel.level = switch Fish.shared.placement {
        case .floating: .floating
        case .desktop: NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        }
    }
}
