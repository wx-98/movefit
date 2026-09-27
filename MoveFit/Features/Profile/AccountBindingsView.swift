import SwiftUI

struct AccountBindingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var remote: RemoteFeatureViewModel
    @State private var providerToUnlink: SocialProvider?

    var body: some View {
        Form {
            if model.accountSession == nil {
                Section {
                    Label("请先登录后端账号，再管理第三方身份。", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            } else {
                Section {
                    switch remote.identityStatus {
                    case .loading:
                        ProgressView("正在读取绑定状态…")
                    case .unavailable, .cached:
                        Text("当前无法确认最新绑定状态，请刷新后重试。")
                            .foregroundColor(.secondary)
                    case .remote:
                        Text(LocalizedStringKey(
                            remote.identities.isEmpty ? "尚未绑定第三方身份。" : "仅展示服务端返回的脱敏身份信息。"
                        ))
                            .foregroundColor(.secondary)
                    case .notLoaded, .localFallback, .signInRequired:
                        Text("正在等待服务端绑定状态。")
                            .foregroundColor(.secondary)
                    }
                }
                Section("第三方身份") {
                    ForEach(SocialProvider.allCases, id: \.self) { provider in
                        identityRow(provider)
                    }
                }
                Section {
                    Button("刷新绑定状态") {
                        Task { await remote.refreshIdentities() }
                    }
                    .disabled(model.accountOperationInProgress)
                }
            }
        }
        .navigationTitle("账号绑定")
        .task {
            if model.accountSession != nil { await remote.refreshIdentities() }
        }
        .confirmationDialog(
            "确认解绑此身份？",
            isPresented: Binding(
                get: { providerToUnlink != nil },
                set: { if !$0 { providerToUnlink = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let provider = providerToUnlink {
                Button("解绑 \(title(for: provider))", role: .destructive) {
                    providerToUnlink = nil
                    Task {
                        _ = await model.unlinkSocial(provider: provider)
                    }
                }
            }
            Button("取消", role: .cancel) { providerToUnlink = nil }
        }
    }

    private func identityRow(_ provider: SocialProvider) -> some View {
        let linked = remote.identities.first { $0.provider == provider }
        return HStack {
            Image(systemName: symbol(for: provider))
                .foregroundColor(AppColor.primary)
            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                Text(title(for: provider)).font(.headline)
                if let linked {
                    Text(linked.maskedHint ?? "已绑定")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(linked.linkedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text(LocalizedStringKey(provider == .wechat ? "需配置微信 SDK" : "未绑定"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if linked != nil {
                Button("解绑") { providerToUnlink = provider }
                    .foregroundColor(.red)
                    .disabled(model.accountOperationInProgress || remote.identityStatus != .remote)
            } else {
                Button("绑定") {
                    Task {
                        _ = await model.linkSocial(provider: provider)
                    }
                }
                .disabled(model.accountOperationInProgress || remote.identityStatus != .remote)
            }
        }
        .accessibilityIdentifier("identity-\(provider.rawValue)")
    }

    private func title(for provider: SocialProvider) -> String {
        switch provider {
        case .apple: return "Apple ID"
        case .wechat: return "微信"
        case .google: return "Google"
        }
    }

    private func symbol(for provider: SocialProvider) -> String {
        switch provider {
        case .apple: return "applelogo"
        case .wechat: return "message.fill"
        case .google: return "globe"
        }
    }
}
