import Foundation

enum RemoteContentDTO {
    struct Article: Decodable {
        let articleId: UUID
        let title: String
        let summary: String
        let category: String
        let locale: String
        let bodyMarkdown: String
        let disclaimer: String?
        let revision: Int
        let publishedAt: String
        let updatedAt: String

        func domain() throws -> RemoteArticle {
            guard let publishedAt = BackendDateParser.date(from: publishedAt),
                  let updatedAt = BackendDateParser.date(from: updatedAt) else {
                throw BackendError.invalidResponse
            }
            return RemoteArticle(
                id: articleId,
                title: title,
                summary: summary,
                category: category,
                locale: locale,
                bodyMarkdown: bodyMarkdown,
                disclaimer: disclaimer,
                revision: revision,
                publishedAt: publishedAt,
                updatedAt: updatedAt
            )
        }
    }

    struct HelpArticle: Decodable {
        let helpArticleId: UUID
        let title: String
        let category: String
        let locale: String
        let bodyMarkdown: String
        let revision: Int
        let updatedAt: String

        func domain() throws -> RemoteHelpArticle {
            guard let updatedAt = BackendDateParser.date(from: updatedAt) else {
                throw BackendError.invalidResponse
            }
            return RemoteHelpArticle(
                id: helpArticleId,
                title: title,
                category: category,
                locale: locale,
                bodyMarkdown: bodyMarkdown,
                revision: revision,
                updatedAt: updatedAt
            )
        }
    }

    struct Favorite: Decodable {
        let articleId: UUID
        let isFavorite: Bool
        let version: Int
        let updatedAt: String

        func domain() throws -> RemoteArticleFavorite {
            guard let updatedAt = BackendDateParser.date(from: updatedAt) else {
                throw BackendError.invalidResponse
            }
            return RemoteArticleFavorite(
                articleID: articleId,
                isFavorite: isFavorite,
                version: version,
                updatedAt: updatedAt
            )
        }
    }

    struct FavoriteSummary: Decodable {
        let articleId: UUID
        let title: String
        let summary: String
        let category: String
        let locale: String
        let revision: Int
        let favoriteVersion: Int
        let favoriteUpdatedAt: String

        func domain() throws -> RemoteFavoriteArticleSummary {
            guard let updatedAt = BackendDateParser.date(from: favoriteUpdatedAt) else {
                throw BackendError.invalidResponse
            }
            return RemoteFavoriteArticleSummary(
                id: articleId,
                title: title,
                summary: summary,
                category: category,
                locale: locale,
                revision: revision,
                favoriteVersion: favoriteVersion,
                favoriteUpdatedAt: updatedAt
            )
        }
    }
}
