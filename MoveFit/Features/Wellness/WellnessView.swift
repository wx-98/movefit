import SwiftUI

struct WellnessView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var remote: RemoteFeatureViewModel
    @State private var message: String?
    @State private var favoriteOperations: [UUID: UUID] = [:]
    @State private var favoriteTargets: [UUID: Bool] = [:]

    var body: some View {
        List {
            Section(model.localizer.text("今日建议")) {
                if model.wellnessRecommendations.isEmpty {
                    Label(model.localizer.text("暂无足够的 Apple 健康数据，请先连接或刷新健康数据。"), systemImage: "heart.text.square")
                } else {
                    ForEach(model.wellnessRecommendations, id: \.self) { recommendation in
                        Label(model.localizer.text(recommendation.rawValue), systemImage: recommendation.symbol)
                    }
                }
            }
            if remote.articleStatus == .loading {
                Section(model.localizer.text("服务端文章")) {
                    ProgressView(model.localizer.text("正在读取已发布文章…"))
                }
            } else if remote.articleStatus == .remote || remote.articleStatus == .cached {
                Section(model.localizer.text("服务端已发布内容")) {
                    if remote.articleStatus == .cached {
                        Text(model.localizer.text("当前离线，以下为本次打开应用时读取的内容；收藏写入需要联网。"))
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    ForEach(remote.articles) { article in
                        HStack {
                            NavigationLink(destination: RemoteArticleDetailView(articleID: article.id)) {
                                VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                                    Text(article.title).font(.headline)
                                    Text(article.summary).font(.caption).foregroundColor(.secondary)
                                    Text(article.category).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            Button {
                                Task { await toggleRemoteFavorite(articleID: article.id) }
                            } label: {
                                Image(systemName: remote.favorites.contains { $0.id == article.id }
                                      ? "bookmark.fill" : "bookmark")
                            }
                            .disabled(remote.isWriting)
                            .accessibilityIdentifier("favorite-\(article.id.uuidString)")
                        }
                    }
                    if remote.canLoadMoreArticles {
                        Button(model.localizer.text("加载更多文章")) {
                            Task { await remote.loadMoreArticles(locale: model.contentLocale) }
                        }
                    }
                }
            } else {
                Section(model.localizer.text("本机基础内容")) {
                    Text(model.localizer.text("服务端暂无已发布文章或当前不可用；以下仅为随包内容。"))
                        .font(.footnote).foregroundColor(.secondary)
                    ForEach(model.articles) { article in
                        VStack(alignment: .leading) {
                            Text(model.localizer.text(article.title)).font(.headline)
                            Text(model.localizer.text(article.summary)).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Button(model.localizer.text("重试读取服务端文章")) {
                        Task { await remote.refreshArticles(locale: model.contentLocale) }
                    }
                }
            }
            Section {
                Text(model.localizer.text("内容仅供健康生活参考，不能替代专业医疗诊断。如有持续不适或异常变化，请咨询合格专业人员。"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(model.localizer.text("养护建议"))
        .task {
            if remote.articleStatus == .notLoaded { await remote.refreshArticles(locale: model.contentLocale) }
            if model.accountSession != nil { await remote.refreshFavorites(locale: model.contentLocale) }
        }
        .alert("操作结果", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("知道了") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func toggleRemoteFavorite(articleID: UUID) async {
        guard model.accountSession != nil else {
            message = model.localizer.text("请先登录后端账号。")
            return
        }
        let isFavorite = remote.favorites.contains { $0.id == articleID }
        let operationID = favoriteOperations[articleID] ?? UUID()
        let target = favoriteTargets[articleID] ?? !isFavorite
        favoriteOperations[articleID] = operationID
        favoriteTargets[articleID] = target
        let succeeded = await remote.setFavorite(
            articleID: articleID,
            isFavorite: target,
            locale: model.contentLocale,
            operationID: operationID
        )
        if succeeded {
            favoriteOperations[articleID] = nil
            favoriteTargets[articleID] = nil
        } else {
            message = model.localizer.text("收藏操作未获服务端确认，请检查网络后重试。")
        }
    }
}

private extension WellnessRecommendation {
    var symbol: String {
        switch self {
        case .increaseActivity:
            return "figure.walk"
        case .keepRecovery:
            return "heart"
        case .addStandBreak:
            return "arrow.up.circle"
        }
    }
}
