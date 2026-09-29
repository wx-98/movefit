import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmsCacheClear = false

    var body: some View {
        Form {
            Section(model.localizer.text("Apple 健康")) {
                Text(model.localizer.text("按功能申请最小读取权限。无样本或未授权时显示暂无数据，不会使用演示健康数值。"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Button(model.localizer.text("连接或刷新 Apple 健康")) {
                    Task { await model.connectHealth() }
                }
            }
            Section(model.localizer.text("敏感数据保护")) {
                Toggle(
                    model.localizer.text("在个人页遮挡身体指标"),
                    isOn: Binding(
                        get: { model.hidesSensitiveMetrics },
                        set: { value in Task { await model.setHidesSensitiveMetrics(value) } }
                    )
                )
                Text(model.localizer.text("账号凭据不写入 UserDefaults；访问令牌只保存在 Keychain。Apple 健康原始样本不会上传；登录后的资料与 MoveFit 运动记录会同步到服务端。"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Section(model.localizer.text("本地缓存")) {
                Button(model.localizer.text("清理可重建缓存"), role: .destructive) {
                    confirmsCacheClear = true
                }
                Text(model.localizer.text("只清理离线操作缓存，保留运动记录和健康指标。"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(model.localizer.text("隐私与缓存"))
        .confirmationDialog(model.localizer.text("确认清理可重建缓存？"), isPresented: $confirmsCacheClear) {
            Button(model.localizer.text("确认清理"), role: .destructive) {
                Task { _ = await model.clearRebuildableCache() }
            }
            Button(model.localizer.text("取消"), role: .cancel) {}
        }
    }
}
