import Foundation

/// The app's language, chosen in 设置 → 语言 / Language. It switches at once:
/// the root view is rebuilt with the new language, no relaunch needed. The
/// detector only understands Chinese, so the chat itself stays Chinese.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable {
    case zh, en

    var id: String { rawValue }
    var label: String { self == .zh ? "中文" : "English" }
    var locale: Locale { Locale(identifier: self == .zh ? "zh-Hans" : "en") }

    static let key = "appLanguage"
    static var current: AppLanguage { AppLanguage(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .zh }
}

/// Every user-facing string is written in both languages side by side, so
/// editing one shows the other.
nonisolated func tr(_ zh: String, _ en: String) -> String {
    UserDefaults.standard.string(forKey: AppLanguage.key) == AppLanguage.en.rawValue ? en : zh
}
