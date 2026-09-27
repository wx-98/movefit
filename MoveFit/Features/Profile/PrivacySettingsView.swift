import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmsCacheClear = false

    var body: some View {
        Form {
            Section("Apple 健康") {
                Text("按功能申请最小读取权限。无样本或未授权时显示暂无数据，不会使用演示健康数值。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Button("连接或刷新 Apple 健康") {
                    Task { await model.connectHealth() }
                }
            }
            Section("敏感数据保护") {
                Toggle(
                    "在个人页遮挡身体指标",
                    isOn: Binding(
                        get: { model.hidesSensitiveMetrics },
                        set: { value in Task { await model.setHidesSensitiveMetrics(value) } }
                    )
                )
                Text("账号凭据不写入 UserDefaults；当前版本不保存真实账号令牌，也不会把健康数据上传到服务端。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Section("本地缓存") {
                Button("清理可重建缓存", role: .destructive) {
                    confirmsCacheClear = true
                }
                Text("只清理离线操作缓存，保留运动记录和健康指标。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("隐私与缓存")
        .confirmationDialog("确认清理可重建缓存？", isPresented: $confirmsCacheClear) {
            Button("确认清理", role: .destructive) {
                Task { _ = await model.clearRebuildableCache() }
            }
            Button("取消", role: .cancel) {}
        }
    }
}
