import Foundation

struct Quote: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let source: String
    /// The words leave an empty bubble before it, too, goes away.
    var leavesSilence = false
}

/// Keep the words' layout while they fall silent, without replacing them
/// with a written description of silence.
struct Notice: Equatable {
    let quote: Quote
    var silent = false
}

/// The fish's few words, in the original Chinese, checked against the texts
/// they cite (CBETA for the Buddhist canon).
enum Zen {
    /// What the fish says, in order, one line on the first knock by hand each
    /// day, each line once. It opens with Bodhidharma telling Emperor Wu there
    /// is no merit and ends with Vimalakirti's silence; after that, it only knocks.
    static let sayings = [
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
    static let whyFish = Quote(
        text: "鱼昼夜常醒，刻木象形击之，所以警昏惰也。",
        source: "《敕修百丈清规》")
}
