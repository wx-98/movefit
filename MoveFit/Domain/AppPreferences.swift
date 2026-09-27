import Foundation

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"

    var id: String { rawValue }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case simplifiedChinese = "简体中文"

    var id: String { rawValue }
}
