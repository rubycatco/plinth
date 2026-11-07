import PlinthCore
import SwiftUI

@main
struct PlinthApp: App {
    @State private var fish = Fish()

    var body: some Scene {
        WindowGroup {
            FishScreen()
                .environment(fish)
        }
    }
}

/// The fish on rice paper, alone. Like the Mac's, it keeps no count and shows
/// no clock, so the status bar keeps out of the way too.
struct FishScreen: View {
    /// The rice paper of the Mac's Settings › Why a Fish. It stays paper in
    /// Dark Mode too; ink needs a light ground.
    static let paper = Color(red: 0.953, green: 0.933, blue: 0.890)

    @Environment(Fish.self) private var fish
    /// A finger on the fish, which knocks once as it goes down.
    @GestureState private var pressed = false

    var body: some View {
        GeometryReader { screen in
            // The Mac's largest fish, or smaller on a narrow screen.
            let side = min(300, min(screen.size.width, screen.size.height) * 0.8)
            SpriteFish(pack: fish.pack, side: side, swing: fish.swing, impacts: fish.impacts, bloom: fish.bloom)
                .frame(width: side, height: side)
                .contentShape(Rectangle())
                // The mallet swings as the finger goes down, as a drum answers
                // a stick, not when it lifts.
                .gesture(DragGesture(minimumDistance: 0).updating($pressed) { value, pressed, _ in
                    guard !pressed else { return }
                    pressed = true
                    fish.knock(at: value.startLocation.x / side)
                })
                // VoiceOver reads it as a button that knocks, and can press it.
                .accessibilityElement()
                .accessibilityLabel("Knock")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { fish.knock(at: fish.pack.strike.x) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Self.paper)
        .statusBarHidden()
    }
}
