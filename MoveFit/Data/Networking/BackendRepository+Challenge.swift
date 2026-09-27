import Foundation

extension BackendRepository: ChallengeRemoteProviding {
    func challenges(locale: String, cursor: String?) async throws -> RemotePage<RemoteChallenge> {
        guard isValidChallengeLocale(locale) else { throw RemoteServiceError.invalidRequest }
        var query = [URLQueryItem(name: "locale", value: locale), URLQueryItem(name: "limit", value: "20")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        do {
            let response = try await client.send(
                BackendRequest(path: "api/v1/challenges", queryItems: query),
                as: RemotePageDTO<RemoteChallengeDTO.Item>.self
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

    func challenge(id: UUID, locale: String) async throws -> RemoteChallenge {
        guard isValidChallengeLocale(locale) else { throw RemoteServiceError.invalidRequest }
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/challenges/\(id.uuidString)",
                    queryItems: [URLQueryItem(name: "locale", value: locale)]
                ),
                as: RemoteChallengeDTO.Item.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func participations(cursor: String?) async throws -> RemotePage<RemoteChallengeParticipation> {
        var query = [URLQueryItem(name: "limit", value: "20")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/me/challenge-participations",
                    queryItems: query,
                    requiresAuthentication: true
                ),
                as: RemotePageDTO<RemoteChallengeDTO.Participation>.self
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

    func join(
        challengeID: UUID,
        locale: String,
        operationID: UUID
    ) async throws -> RemoteChallengeParticipation {
        guard isValidChallengeLocale(locale) else { throw RemoteServiceError.invalidRequest }
        let body = try await client.encode(RemoteChallengeDTO.JoinRequest(locale: locale))
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/challenges/\(challengeID.uuidString)/participations",
                    method: .post,
                    body: body,
                    requiresAuthentication: true,
                    idempotencyKey: operationID
                ),
                as: RemoteChallengeDTO.Participation.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func leave(challengeID: UUID, operationID: UUID) async throws {
        do {
            try await client.sendWithoutResponse(
                BackendRequest(
                    path: "api/v1/challenges/\(challengeID.uuidString)/participations/current",
                    method: .delete,
                    requiresAuthentication: true,
                    idempotencyKey: operationID
                )
            )
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func leaderboard(challengeID: UUID, cursor: String?) async throws -> RemoteLeaderboard {
        var query = [URLQueryItem(name: "limit", value: "20")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/challenges/\(challengeID.uuidString)/leaderboard",
                    queryItems: query,
                    allowsOptionalAuthentication: true
                ),
                as: RemoteChallengeDTO.Leaderboard.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    private func isValidChallengeLocale(_ locale: String) -> Bool {
        (2...16).contains(locale.count)
    }
}
