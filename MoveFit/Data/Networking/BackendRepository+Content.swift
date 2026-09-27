import Foundation

extension BackendRepository: ContentProviding {
    func articles(locale: String, cursor: String?) async throws -> RemotePage<RemoteArticle> {
        guard ["en", "zh-Hans"].contains(locale) else { throw RemoteServiceError.invalidRequest }
        var query = [URLQueryItem(name: "locale", value: locale), URLQueryItem(name: "limit", value: "20")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        do {
            let response = try await client.send(
                BackendRequest(path: "api/v1/articles", queryItems: query),
                as: RemotePageDTO<RemoteContentDTO.Article>.self
            )
            return RemotePage(
                items: try response.items.map { try $0.domain() },
                nextCursor: response.nextCursor,
                hasMore: response.hasMore
            )
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func article(id: UUID, locale: String) async throws -> RemoteArticle {
        guard ["en", "zh-Hans"].contains(locale) else { throw RemoteServiceError.invalidRequest }
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/articles/\(id.uuidString)",
                    queryItems: [URLQueryItem(name: "locale", value: locale)]
                ),
                as: RemoteContentDTO.Article.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func favorites(
        locale: String,
        cursor: String?
    ) async throws -> RemotePage<RemoteFavoriteArticleSummary> {
        guard ["en", "zh-Hans"].contains(locale) else { throw RemoteServiceError.invalidRequest }
        var query = [URLQueryItem(name: "locale", value: locale), URLQueryItem(name: "limit", value: "20")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/me/article-favorites",
                    queryItems: query,
                    requiresAuthentication: true
                ),
                as: RemotePageDTO<RemoteContentDTO.FavoriteSummary>.self
            )
            return RemotePage(
                items: try response.items.map { try $0.domain() },
                nextCursor: response.nextCursor,
                hasMore: response.hasMore
            )
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func setFavorite(
        articleID: UUID,
        isFavorite: Bool,
        operationID: UUID
    ) async throws -> RemoteArticleFavorite? {
        let request = BackendRequest(
            path: "api/v1/me/article-favorites/\(articleID.uuidString)",
            method: isFavorite ? .put : .delete,
            requiresAuthentication: true,
            idempotencyKey: operationID
        )
        do {
            if isFavorite {
                let response = try await client.send(request, as: RemoteContentDTO.Favorite.self)
                return try response.domain()
            }
            try await client.sendWithoutResponse(request)
            return nil
        } catch {
            throw RemoteServiceError.map(error)
        }
    }
}
