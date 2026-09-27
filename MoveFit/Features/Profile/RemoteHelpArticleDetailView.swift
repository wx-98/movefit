import SwiftUI

struct RemoteHelpArticleDetailView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var remote: RemoteFeatureViewModel
    let articleID: UUID

    @State private var article: RemoteHelpArticle?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if let article {
                    Text(article.title).font(.largeTitle.bold())
                    Text("\(article.category) · 更新于 \(article.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundColor(.secondary)
                    Text(article.bodyMarkdown).font(.body)
                } else if isLoading {
                    ProgressView("正在读取帮助文章…")
                } else {
                    EmptyStateView(title: "帮助文章暂不可用", message: "请检查网络后重试。", symbol: "questionmark.circle")
                    Button("重试") { Task { await load() } }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("帮助文章")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            article = try await remote.helpArticle(id: articleID, locale: model.contentLocale)
        } catch {
            article = nil
        }
    }
}
