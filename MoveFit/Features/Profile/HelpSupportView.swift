import SwiftUI

struct HelpSupportView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var remote: RemoteFeatureViewModel

    var body: some View {
        List {
            if remote.helpStatus == .loading {
                Section("服务端帮助文章") {
                    ProgressView("正在读取帮助文章…")
                }
            } else if remote.helpStatus == .remote || remote.helpStatus == .cached {
                Section("服务端帮助文章") {
                    if remote.helpStatus == .cached {
                        Text("当前离线，以下为本次打开应用时读取的帮助内容。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    ForEach(remote.helpArticles) { article in
                        NavigationLink(destination: RemoteHelpArticleDetailView(articleID: article.id)) {
                            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                                Text(article.title).font(.headline)
                                Text(article.category).font(.caption).foregroundColor(.secondary)
                                Text(article.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    if remote.canLoadMoreHelp {
                        Button("加载更多帮助文章") {
                            Task { await remote.loadMoreHelp(locale: model.contentLocale) }
                        }
                    }
                }
            } else {
                Section("随包常见问题") {
                    Text("服务端暂无已发布帮助或当前不可用，以下为随包内容。")
                        .font(.footnote).foregroundColor(.secondary)
                    faq("为什么健康数据为空？", "HealthKit 无法向应用区分“拒绝读取”和“没有样本”。请在系统健康权限中检查，并确认健康 App 内已有对应数据。")
                    faq("为什么运动没有路线？", "Apple 健康样本不一定包含可读取路线；MoveFit 户外运动还要求使用期间定位权限和有效定位点。")
                    faq("为什么账号无法绑定？", "请先确认已登录，再到“账号绑定”页刷新；第三方授权或服务端未配置时不会伪造绑定。")
                    faq("动作库来自哪里？", "优先读取动作目录后端；服务不可达时才显示随应用发布并审核的基础动作。")
                    Button("重试读取服务端帮助") {
                        Task { await remote.refreshHelp(locale: model.contentLocale) }
                    }
                }
            }
            Section("排查步骤") {
                Text("1. 检查系统设置中的健康与定位权限")
                Text("2. 回到应用的“健康与设备”点击刷新")
                Text("3. 确认设备时间、时区和健康 App 样本日期")
                Text("4. 仍有问题时记录系统版本、机型和操作步骤，不要附带健康明细或精确路线")
            }
            Section("我的支持工单") {
                if model.accountSession == nil {
                    Text("请先登录后端账号，再创建或查看本人工单。")
                        .font(.footnote).foregroundColor(.secondary)
                } else {
                    NavigationLink("创建工单", destination: SupportTicketComposerView())
                    switch remote.ticketStatus {
                    case .remote, .cached:
                        if remote.ticketStatus == .cached {
                            Text("当前显示本次打开应用时读取的工单；操作需要联网。")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                        ForEach(remote.tickets) { ticket in
                            NavigationLink(destination: SupportTicketDetailView(ticketID: ticket.id)) {
                                VStack(alignment: .leading) {
                                    Text(ticket.subject).font(.headline)
                                    Text(ticket.status).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        if remote.canLoadMoreTickets {
                            Button("加载更多工单") { Task { await remote.loadMoreTickets() } }
                        }
                    case .loading:
                        ProgressView("正在读取我的工单…")
                    case .notLoaded, .localFallback, .signInRequired, .unavailable:
                        Text("暂无法读取工单，请刷新后重试。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    Button("刷新工单") { Task { await remote.refreshTickets() } }
                }
            }
        }
        .navigationTitle("帮助与支持")
        .task {
            if remote.helpStatus == .notLoaded { await remote.refreshHelp(locale: model.contentLocale) }
            if model.accountSession != nil { await remote.refreshTickets() }
        }
    }

    private func faq(_ title: String, _ answer: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title).font(.headline)
            Text(answer).font(.footnote).foregroundColor(.secondary)
        }
        .padding(.vertical, AppSpacing.tiny)
    }
}
