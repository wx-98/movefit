import Foundation

extension BackendRepository: SupportProviding {
    func helpArticles(locale: String, cursor: String?) async throws -> RemotePage<RemoteHelpArticle> {
        guard ["en", "zh-Hans"].contains(locale) else { throw RemoteServiceError.invalidRequest }
        var query = [URLQueryItem(name: "locale", value: locale), URLQueryItem(name: "limit", value: "20")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        do {
            let response = try await client.send(
                BackendRequest(path: "api/v1/help-articles", queryItems: query),
                as: RemotePageDTO<RemoteContentDTO.HelpArticle>.self
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

    func helpArticle(id: UUID, locale: String) async throws -> RemoteHelpArticle {
        guard ["en", "zh-Hans"].contains(locale) else { throw RemoteServiceError.invalidRequest }
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/help-articles/\(id.uuidString)",
                    queryItems: [URLQueryItem(name: "locale", value: locale)]
                ),
                as: RemoteContentDTO.HelpArticle.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func tickets(cursor: String?) async throws -> RemotePage<RemoteSupportTicket> {
        var query = [URLQueryItem(name: "limit", value: "50")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/support/tickets",
                    queryItems: query,
                    requiresAuthentication: true
                ),
                as: RemotePageDTO<RemoteSupportDTO.Ticket>.self
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

    func ticket(id: UUID) async throws -> RemoteSupportTicketDetail {
        do {
            let response = try await client.send(
                BackendRequest(path: "api/v1/support/tickets/\(id.uuidString)", requiresAuthentication: true),
                as: RemoteSupportDTO.Detail.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func createTicket(
        category: String,
        subject: String,
        message: String,
        operationID: UUID
    ) async throws -> RemoteSupportTicketDetail {
        guard !category.isEmpty, !subject.isEmpty, !message.isEmpty else {
            throw RemoteServiceError.invalidRequest
        }
        let body = try await client.encode(
            RemoteSupportDTO.CreateRequest(category: category, subject: subject, message: message)
        )
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/support/tickets",
                    method: .post,
                    body: body,
                    requiresAuthentication: true,
                    idempotencyKey: operationID
                ),
                as: RemoteSupportDTO.Created.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func reply(
        ticketID: UUID,
        message: String,
        operationID: UUID
    ) async throws -> RemoteSupportTicketReply {
        guard !message.isEmpty else { throw RemoteServiceError.invalidRequest }
        let body = try await client.encode(RemoteSupportDTO.ReplyRequest(message: message))
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/support/tickets/\(ticketID.uuidString)/messages",
                    method: .post,
                    body: body,
                    requiresAuthentication: true,
                    idempotencyKey: operationID
                ),
                as: RemoteSupportDTO.Reply.self
            )
            return try response.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }

    func close(ticketID: UUID, operationID: UUID) async throws -> RemoteSupportTicket {
        do {
            let response = try await client.send(
                BackendRequest(
                    path: "api/v1/support/tickets/\(ticketID.uuidString)/actions/close",
                    method: .post,
                    requiresAuthentication: true,
                    idempotencyKey: operationID
                ),
                as: RemoteSupportDTO.Closed.self
            )
            return try response.ticket.domain()
        } catch {
            throw RemoteServiceError.map(error)
        }
    }
}
