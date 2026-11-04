import AppIntents
import SwiftUI
import WidgetKit

/// The widget's Knock button. It runs in the widget's own sandboxed process,
/// so it tells Plinth to knock with a distributed notification, which a
/// sandbox may post. Plinth knocks as it does for `plinth://knock`.
struct KnockFromWidget: AppIntent {
    static let title: LocalizedStringResource = "Knock"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        DistributedNotificationCenter.default().postNotificationName(
            .init("dev.rubycat.plinth.knock"), object: nil, userInfo: nil, deliverImmediately: true)
        return .result()
    }
}

struct FishEntry: TimelineEntry {
    let date: Date
}

struct FishProvider: TimelineProvider {
    func placeholder(in context: Context) -> FishEntry { FishEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (FishEntry) -> Void) { completion(FishEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FishEntry>) -> Void) {
        completion(Timeline(entries: [FishEntry(date: .now)], policy: .never))
    }
}

struct FishWidgetView: View {
    var body: some View {
        Button(intent: KnockFromWidget()) {
            Image(nsImage: Self.fish)
                .resizable()
                .scaledToFit()
        }
        .buttonStyle(.plain)
        .containerBackground(for: .widget) { Color.black }
    }

    /// The wooden fish. scripts/build_app.sh copies it into the widget's own
    /// bundle, since the sandbox keeps the widget out of the app's.
    static let fish = Bundle.main.image(forResource: "fish") ?? NSImage()
}

struct FishWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "dev.rubycat.plinth.fish", provider: FishProvider()) { _ in
            FishWidgetView()
        }
        .configurationDisplayName("Wooden Fish")
        .description("Click to knock.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct PlinthWidgets: WidgetBundle {
    var body: some Widget {
        FishWidget()
    }
}
