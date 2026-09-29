import SwiftUI

struct RemoteArticleDetailView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var remote: RemoteFeatureViewModel
    let articleID: UUID

    @State private var article: RemoteArticle?
    @State private var isLoading = false
    @State private var message: String?
    @State private var favoriteOperationID = UUID()
    @State private var pendingFavoriteTarget: Bool?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if let article {
                    Text(article.title).font(.largeTitle.bold())
                    Text(model.localizer.formatted(
                        "articles.updated.format",
                        article.category,
                        article.updatedAt.formatted(date: .abbreviated, time: .omitted)
                    ))
                        .font(.caption).foregroundColor(.secondary)
                    Text(article.summary).font(.subheadline)
                    Text(article.bodyMarkdown).font(.body)
                    if let disclaimer = article.disclaimer {
                        Text(disclaimer).font(.footnote).foregroundColor(.secondary)
                    }
                    Button(model.localizer.text(remote.favorites.contains { $0.id == articleID } ? "取消收藏" : "收藏文章")) {
                        Task { await toggleFavorite() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(remote.isWriting)
                } else if isLoading {
                    ProgressView(model.localizer.text("正在读取文章…"))
                } else {
                    EmptyStateView(
                        title: model.localizer.text("文章暂不可用"),
                        message: model.localizer.text("请检查网络后重试。"),
                        symbol: "doc.text"
                    )
                    Button(model.localizer.text("重试")) { Task { await load() } }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(model.localizer.text("健康文章"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("操作结果", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("知道了") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            article = try await remote.article(id: articleID, locale: model.contentLocale)
        } catch {
            message = model.localizer.text("无法读取文章，请检查网络后重试。")
        }
    }

    private func toggleFavorite() async {
        guard model.accountSession != nil else {
            message = model.localizer.text("请先登录后端账号。")
            return
        }
        let isFavorite = remote.favorites.contains { $0.id == articleID }
        let target = pendingFavoriteTarget ?? !isFavorite
        let succeeded = await remote.setFavorite(
            articleID: articleID,
            isFavorite: target,
            locale: model.contentLocale,
            operationID: favoriteOperationID
        )
        if succeeded {
            pendingFavoriteTarget = nil
            favoriteOperationID = UUID()
        } else {
            pendingFavoriteTarget = target
            message = model.localizer.text("收藏操作未获服务端确认，请检查网络后重试。")
        }
    }
}
