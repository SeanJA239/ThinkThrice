// ThinkThriceRules.swift：关键词规则层（写死），配合 ThinkThriceClassifier 使用。
// 来自模型组交付包（2026-11-21，v2c）。接入 CalmCore 时只加了 public / Sendable，判定逻辑和词表原样未改。
// 模型负责「语气」，规则负责模型学不到的东西：
//   1. 辱骂/狠话词：模型漏判的（如「脑子有问题」）直接兜住
//   2. 深夜 + 收件人专属词：发给前任的「想复合」、发给老板的「不干了」，语气平静但同样冲动
//   3. 三问回答：明显的反思用语（好好说、说重了）不判为「还在生气」
import Foundation

public enum Recipient: String, Codable, Sendable { case ex, boss, other }   // 来自联系人标签

public enum LockReason: String, Sendable {
    case none = "不锁"
    case model = "语气激动（模型）"
    case insult = "辱骂/狠话（关键词）"
    case reconcile = "深夜想复合（关键词）"
    case quit = "深夜怼老板/想辞职（关键词）"
    case bossRant = "怼老板（关键词）"
}

public struct Verdict: Sendable {
    public let lock: Bool
    public let score: Double       // 0~100，展示用
    public let reason: LockReason  // 锁定页按原因换提示文案
    public let matched: [String]   // 命中的关键词，可在锁定页高亮
}

public enum ThinkThriceRules {
    public struct WordList: Sendable {
        public let words: [String]
        public var except: [String] = []   // 先从文本里删掉这些词再匹配，防误伤
        public func hits(_ text: String) -> [String] {
            var t = text.lowercased().replacingOccurrences(of: " ", with: "")
            for e in except { t = t.replacingOccurrences(of: e, with: "") }
            return words.filter { t.contains($0) }
        }
    }

    /// 辱骂 / 狠话：任何收件人、任何时间命中都锁
    public static let insult = WordList(words: [
        "畜生", "不是人", "不是东西", "算什么东西", "王八蛋", "混蛋", "人渣", "败类", "废物", "狗东西", "白眼狼",
        "傻逼", "傻b", "煞笔", "傻叉", "脑残", "脑子有问题", "脑子有病", "脑子进水", "你有病", "有病吧", "有病啊", "神经病",
        "去死", "滚", "贱人", "犯贱", "不要脸", "他妈", "tmd", "你妈的", "操你", "草泥马", "闭嘴", "给我等着",
        "你是垃圾", "就是垃圾", "真垃圾", "垃圾人", "就恶心", "你真恶心", "恶心死", "让人恶心",
        "恨你", "受够了", "忍不了", "气死", "烦死", "别烦我", "吸血鬼", "黑心",
        // 2026-11-21 骂老板探针补充：「你脑子是不是有问题」这类插了字的说法，模型给分偏低
        "脑子是不是", "脑子有坑", "脑子坏", "脑子被门夹", "脑袋有问题", "是不是有病", "你有毛病", "是不是有毛病",
        "什么玩意", "你还是人吗", "良心被狗", "有本事你", "要我命", "骗子", "有完没完",
        // 2026-11-21 路演前补充：骂人常用词
        "脑子不好", "脑子不正常", "没脑子", "长没长脑子", "有没有脑子", "猪脑子", "智障", "弱智", "白痴", "蠢货", "蠢猪", "饭桶",
        "你疯了", "是不是疯了", "你是不是傻", "你傻吗", "你瞎吗", "臭不要脸", "去你的", "去你妈", "放屁", "狗屁", "屁话",
        "你算老几", "算个屁", "算个什么", "不当人", "不把人当人", "看你不爽", "走着瞧", "你等着",
        "瞎了眼", "除了会骂人",   // 盲测 1 补充（发给前任也要锁）
    ], except: ["滚动", "滚烫", "打滚", "翻滚", "滚雪球", "滚床单", "滚圆", "滚筒", "滚轮", "摇滚", "滚瓜烂熟",
                "不是人家", "不恨你", "没恨你"])

    /// 深夜发给前任：想复合 / 思念
    public static let reconcile = WordList(words: [
        "复合", "和好", "想你", "想见你", "还爱你", "我爱你", "还喜欢你", "忘不了", "放不下", "舍不得", "重新开始",
        // 「在吗」故意不放：路演脚本里「在吗」要正常送达，「我想复合了」才锁
        "回到我身边", "回来吧", "回来好不好", "还有可能", "梦到你", "梦见你", "睡不着", "你还好吗", "最近好吗", "还记得我们",
        "喜欢你", "放下你", "没放下", "在一起", "原谅我", "再给我一次机会", "过得好吗", "过得还好吗",
        // 盲测 1 补充。「我错了」已移除：三问之后改写成「对不起，是我错了，我不该那样说」应该能发出去
        "见一面", "见个面", "没忘了你", "忘不掉", "一直没忘", "身边有人", "新女朋友", "新男朋友", "有新欢", "还单身",
        "你的声音", "喝多了", "喝了点酒", "喝醉了",
    ], except: ["不想你"])

    /// 深夜发给老板：冲动辞职 / 怼老板
    public static let quit = WordList(words: [
        "不干了", "不想干了", "辞职", "离职", "不伺候", "谁爱干谁干", "爱谁干谁干", "破公司", "画饼", "压榨",
        "周扒皮", "资本家", "劳动仲裁", "老子",
        "谁爱做谁做", "我不来了", "不做了", "不想做了",   // 盲测 1 补充
    ])

    /// 发给老板的狠话 / 吐槽：不分时间，发给老板就锁（「加班」本身不算，「今天加班到很晚，好累啊」要能送达）
    public static let bossRant = WordList(words: [
        "天天加班", "天天让人加班", "天天让我们加班", "天天让我加班", "又加班", "又让我加班", "又要加班", "加什么班", "加个屁",
        "无偿加班", "白加班", "加班费", "996", "007", "压榨", "剥削", "画饼", "画大饼", "大饼", "pua", "当牛做马", "牛马",
        "扣工资", "扣我工资", "扣我钱", "拖欠工资", "欠薪", "不发工资", "工资都发不", "年终奖呢", "黑心", "无良",
        "破公司", "破工作", "破班", "垃圾公司", "垃圾老板", "谁爱干谁干", "爱谁干谁干", "谁爱上谁上", "你爱找谁找谁",
        "不干了", "不想干了", "不伺候", "老子", "老娘", "炒了你", "开除我", "劳动仲裁", "去仲裁", "劳动局", "告你", "举报你",
        "周扒皮", "资本家", "吸血", "背锅", "甩锅", "你行你上", "你自己干", "你自己来", "凭什么", "受不了你", "忍你很久",
        "早就想骂", "迟早倒闭", "瞎了眼",
    ])

    /// 发给老板的客气话：没命中任何狠话时，不让模型单独把它锁掉（模型会把「请半天假去医院，可以吗？」判到 0.9）
    public static let politeBoss = WordList(words: ["您", "收到", "好的老板", "谢谢", "辛苦", "请假", "麻烦", "可以吗",
                                             "病假", "事假", "年假", "调休", "请一天", "请一个", "请个假", "请两天", "请半天",
                                             "身体不舒服", "不舒服", "发烧", "感冒", "看病", "医院"])

    /// 三问回答：明显还在气头上
    public static let angryAnswer = WordList(words: ["个屁", "屁事", "活该", "就要发", "我没错", "我就要"])
    /// 三问回答：明显在反思（模型偶尔把「不能接受」这类词判高）
    public static let calmAnswer = WordList(words: ["好好说", "冷静", "明天再说", "说重了", "太重了", "不该", "道歉", "换个说法", "心平气和"])

    /// 聊天消息。modelProb 用 ThinkThriceClassifier.messageProbability
    public static func judgeMessage(_ text: String, modelProb p: Double, to: Recipient,
                             lateNight: Bool, contextFactor: Double) -> Verdict {
        let ins = insult.hits(text)
        if !ins.isEmpty { return Verdict(lock: true, score: 100, reason: .insult, matched: ins) }
        if to == .boss {
            let hit = bossRant.hits(text)
            if !hit.isEmpty { return Verdict(lock: true, score: 100, reason: .bossRant, matched: hit) }
        }
        if lateNight {
            let (list, reason): (WordList?, LockReason) = to == .ex ? (reconcile, .reconcile) : to == .boss ? (quit, .quit) : (nil, .none)
            if let hit = list?.hits(text), !hit.isEmpty { return Verdict(lock: true, score: 100, reason: reason, matched: hit) }
        }
        // 纯打招呼（「在吗」「在吗？」「在吗在吗」）直接送达，不交给模型：路演脚本第 3 句，v3c 模型会把「在吗」判到 0.55
        if isGreetingOnly(text) { return Verdict(lock: false, score: 0, reason: .none, matched: []) }
        // 规则分：只看连续的感叹/问号（「！！」「？！」），平静消息恒为 0，不影响 0.42 的推导
        let rule: Double = ["！！", "!!", "？！", "?!", "！？", "？？", "??"].contains { text.contains($0) } ? 50 : 0
        if to == .boss, rule == 0, !politeBoss.hits(text).isEmpty {
            return Verdict(lock: false, score: min(59, 0.7 * p * 100), reason: .none, matched: [])
        }
        let score = min(100, (0.7 * p * 100 + 0.3 * rule) * contextFactor)
        return Verdict(lock: score >= 60, score: score, reason: score >= 60 ? .model : .none, matched: [])
    }

    public static let greetings = ["在不在", "在吗", "在么", "在嘛", "在没", "hello", "hi", "你好", "嗨", "哈喽"]
    public static func isGreetingOnly(_ text: String) -> Bool {
        var t = text.lowercased().filter { !" ，。！？!?,.~～…、".contains($0) }
        if t.isEmpty { return false }
        for g in greetings { t = t.replacingOccurrences(of: g, with: "") }
        return t.isEmpty
    }

    /// 三问回答是否「还在生气」。modelProb 用 ThinkThriceClassifier.answerProbability
    public static func answerStillAngry(_ text: String, modelProb p: Double) -> (angry: Bool, matched: [String]) {
        let hit = insult.hits(text) + angryAnswer.hits(text)
        if !hit.isEmpty { return (true, hit) }
        if !calmAnswer.hits(text).isEmpty { return (false, []) }
        return (p >= 0.8, [])
    }
}
