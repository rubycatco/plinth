import Foundation

public struct Quote: Identifiable, Equatable {
    public let id = UUID()
    public let text: String
    public let source: String
    /// The words leave an empty bubble before it, too, goes away.
    public var leavesSilence = false

    public init(text: String, source: String, leavesSilence: Bool = false) {
        self.text = text
        self.source = source
        self.leavesSilence = leavesSilence
    }

    /// How long the words stay, in seconds: long enough to read slowly.
    public var readingTime: Double { min(14, max(7, Double(text.count) * 0.4)) }
}

/// Keep the words' layout while they fall silent, without replacing them
/// with a written description of silence.
public struct Notice: Equatable {
    public let quote: Quote
    public var silent = false

    public init(quote: Quote, silent: Bool = false) {
        self.quote = quote
        self.silent = silent
    }
}

/// The fish's few words, in the original Chinese, checked against the texts
/// they cite (CBETA for the Buddhist canon).
public enum Zen {
    /// What the fish says, in order, one line on the first knock by hand each
    /// day, each line once. It opens with Bodhidharma telling Emperor Wu there
    /// is no merit and ends with Vimalakirti's silence; after that, it only knocks.
    public static let sayings = [
        Quote(text: "梁武帝问：造寺写经度僧，有何功德？\n达摩曰：并无功德。", source: "《景德传灯录》"),
        Quote(text: "吃茶去。", source: "赵州从谂"),
        Quote(text: "饥来吃饭，困来即眠。", source: "大珠慧海"),
        Quote(text: "平常心是道。", source: "南泉普愿"),
        Quote(text: "日日是好日。", source: "云门文偃"),
        Quote(text: "春有百花秋有月，夏有凉风冬有雪。\n若无闲事挂心头，便是人间好时节。", source: "无门慧开《无门关》"),
        Quote(text: "至道无难，唯嫌拣择。\n但莫憎爱，洞然明白。", source: "僧璨《信心铭》"),
        Quote(text: "李翱问：如何是道？\n药山指天又指地曰：云在青天水在瓶。", source: "《祖堂集》"),
        Quote(text: "一切有为法，如梦幻泡影，\n如露亦如电，应作如是观。", source: "《金刚经》"),
        Quote(text: "应无所住，而生其心。", source: "《金刚经》"),
        Quote(text: "本来无一物，何处惹尘埃。", source: "慧能《六祖坛经》"),
        Quote(text: "不思善，不思恶，\n正与么时，那个是明上座本来面目？", source: "慧能《六祖坛经》"),
        Quote(text: "放下着。", source: "赵州从谂"),
        Quote(text: "文殊师利问：何等是菩萨入不二法门？", source: "《维摩诘所说经》", leavesSilence: true),
    ]

    /// Why a fish: from the Baizhang monastic rules, on the wooden fish.
    public static let whyFish = Quote(
        text: "鱼昼夜常醒，刻木象形击之，所以警昏惰也。",
        source: "《敕修百丈清规》")

    /// The line to say on a knock by hand now, if one is due, which is then
    /// kept as said: the next, on the first such knock each day (from 4 a.m.).
    /// After the last, none. `defaults` keeps how many have been said, and
    /// the day of the last.
    public static func nextSaying(in defaults: UserDefaults = .standard) -> Quote? {
        let said = defaults.integer(forKey: "said")
        guard said < sayings.count else { return nil }
        let today = Self.today()
        guard defaults.string(forKey: "lastSaidDay") != today else { return nil }
        defaults.set(said + 1, forKey: "said")
        defaults.set(today, forKey: "lastSaidDay")
        return sayings[said]
    }

    /// A temple's day begins when the board is struck to wake the hall, before
    /// dawn, not at midnight: a knock at one in the morning is still last night.
    private static func today() -> String {
        let dawn = Calendar.current.date(byAdding: .hour, value: -4, to: .now) ?? .now
        let day = Calendar.current.dateComponents([.year, .month, .day], from: dawn)
        return "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }
}
