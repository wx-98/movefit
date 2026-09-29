import SwiftUI

struct AppearanceLanguageView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("外观") {
                Picker("显示模式", selection: appearanceBinding) {
                    ForEach(AppAppearance.allCases) { value in
                        Label(model.localizer.appearanceName(value), systemImage: value.symbol)
                            .tag(value)
                    }
                }
                .pickerStyle(.inline)
                Text("跟随系统会响应 iPhone 的浅色/深色设置；所有选择均保存在本机。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Section("语言") {
                Picker("应用语言", selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { value in
                        Text(model.localizer.languageName(value)).tag(value)
                    }
                }
                .pickerStyle(.inline)
                Text("当前发布包提供简体中文和英语。选择跟随系统时，其他语言仍回退到简体中文。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("外观与语言")
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(get: { model.appearance }, set: { value in Task { await model.setAppearance(value) } })
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(get: { model.appLanguage }, set: { value in Task { await model.setAppLanguage(value) } })
    }
}

private extension AppAppearance {
    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}
