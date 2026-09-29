import SwiftUI

struct BackendStatusView: View {
    @EnvironmentObject private var model: AppModel
    private let environment = AppEnvironment.current

    var body: some View {
        List {
            Section(model.localizer.text("主业务后端")) {
                Text(environment.backendBaseURL.absoluteString)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .accessibilityIdentifier("backendBaseURLLabel")
                statusRow
            }
            Section(model.localizer.text("动作目录后端")) {
                Text(environment.exerciseBaseURL.absoluteString)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .accessibilityIdentifier("exerciseBaseURLLabel")
                switch model.exerciseCatalogStatus {
                case let .available(version): Label(model.localizer.formatted("backend.catalog.remote.format", version), systemImage: "checkmark.circle.fill")
                case .bundledOnly: Label(model.localizer.text("远程失败，当前为内置降级"), systemImage: "exclamationmark.triangle.fill")
                case .failed: Label(model.localizer.text("不可用"), systemImage: "xmark.circle.fill")
                case .loading: ProgressView(model.localizer.text("正在连接"))
                }
                if let message = model.exerciseCatalogMessage {
                    Text(message).font(.caption).foregroundColor(.secondary)
                }
            }
            Section(model.localizer.text("AI 健康洞察后端")) {
                Text(environment.aiBaseURL.absoluteString)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .accessibilityIdentifier("aiBaseURLLabel")
                Text(model.localizer.text("可用性与权益由健康洞察页面按需检查"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section {
                Button(model.localizer.text("重新检测并同步")) {
                    Task { await model.refreshRemoteData() }
                }
            } footer: {
                Text(model.localizer.text("三个 Debug 地址由 Xcode Build Settings 注入 Info.plist。真机需改为开发机局域网 IP；Release 上线前必须改为 HTTPS。"))
            }
        }
        .navigationTitle(model.localizer.text("后端服务"))
    }

    @ViewBuilder
    private var statusRow: some View {
        switch model.backendConnectionStatus {
        case .notLoaded:
            ProgressView(model.localizer.text("尚未检测"))
        case let .connected(revision):
            Label(model.localizer.formatted("backend.connected.format", revision), systemImage: "checkmark.circle.fill")
                .foregroundColor(AppColor.stand)
        case let .unavailable(message):
            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                Label(model.localizer.text("不可用"), systemImage: "xmark.circle.fill").foregroundColor(AppColor.move)
                Text(message).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
