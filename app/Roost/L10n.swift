import Foundation

/// 极简本地化：中文原文当 key，英文为第二参数。
/// 语言存在 UserDefaults["lang"]，根视图用 .id(lang) 触发整体重建。
enum L {
    static let langKey = "lang"
    static var lang: String { UserDefaults.standard.string(forKey: langKey) ?? "zh" }
    static func t(_ zh: String, _ en: String) -> String { lang == "en" ? en : zh }
}
