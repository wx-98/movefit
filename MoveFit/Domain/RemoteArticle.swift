import Foundation

struct RemoteArticle: Identifiable {
    let id: UUID
    let title: String
    let summary: String
    let category: String
    let locale: String
    let bodyMarkdown: String
    let disclaimer: String?
    let revision: Int
    let publishedAt: Date
    let updatedAt: Date
}

struct RemoteHelpArticle: Identifiable {
    let id: UUID
    let title: String
    let category: String
    let locale: String
    let bodyMarkdown: String
    let revision: Int
    let updatedAt: Date
}

struct RemoteArticleFavorite {
    let articleID: UUID
    let isFavorite: Bool
    let version: Int
    let updatedAt: Date
}

struct RemoteFavoriteArticleSummary: Identifiable {
    let id: UUID
    let title: String
    let summary: String
    let category: String
    let locale: String
    let revision: Int
    let favoriteVersion: Int
    let favoriteUpdatedAt: Date
}
