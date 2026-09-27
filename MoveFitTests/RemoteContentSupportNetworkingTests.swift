import Foundation
import XCTest
@testable import MoveFit

final class RemoteContentSupportNetworkingTests: XCTestCase {
    override func tearDown() {
        ContentSupportURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testArticleAndHelpCatalogsUsePublishedLocaleAndCursor() async throws {
        let repository = try makeContext().repository
        ContentSupportURLProtocolStub.handler = { request in
            let query = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first(where: { $0.name == "locale" })?.value, "zh-Hans")
            XCTAssertEqual(query?.first(where: { $0.name == "cursor" })?.value, "opaque-page")
            if request.url?.path == "/api/v1/articles" {
                return try Self.response(
                    request,
                    status: 200,
                    json: "{\"items\":[\(Self.articleJSON)],\"next_cursor\":null,\"has_more\":false}"
                )
            }
            XCTAssertEqual(request.url?.path, "/api/v1/help-articles")
            return try Self.response(
                request,
                status: 200,
                json: "{\"items\":[\(Self.helpJSON)],\"next_cursor\":null,\"has_more\":false}"
            )
        }

        let articles = try await repository.articles(locale: "zh-Hans", cursor: "opaque-page")
        let help = try await repository.helpArticles(locale: "zh-Hans", cursor: "opaque-page")
        XCTAssertEqual(articles.items.first?.title, "Fictional article")
        XCTAssertEqual(help.items.first?.title, "Fictional help")
    }

    func testFavoriteWriteAndSummaryReadRequireOwnerAndIndependentKeys() async throws {
        let context = try makeContext()
        try await context.store.save(Self.session)
        let articleID = try XCTUnwrap(UUID(uuidString: "a7000000-0000-4000-8000-000000000001"))
        let addID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000301"))
        let removeID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000302"))
        ContentSupportURLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fictional-access")
            switch (request.httpMethod, request.url?.path) {
            case ("PUT", "/api/v1/me/article-favorites/\(articleID.uuidString)"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), addID.uuidString)
                return try Self.response(
                    request,
                    status: 200,
                    json: #"{"article_id":"a7000000-0000-4000-8000-000000000001","is_favorite":true,"version":1,"updated_at":"2026-08-08T10:00:00Z"}"#
                )
            case ("GET", "/api/v1/me/article-favorites"):
                return try Self.response(
                    request,
                    status: 200,
                    json: "{\"items\":[\(Self.favoriteSummaryJSON)],\"next_cursor\":null,\"has_more\":false}"
                )
            case ("DELETE", "/api/v1/me/article-favorites/\(articleID.uuidString)"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), removeID.uuidString)
                return try Self.response(request, status: 204, json: "")
            default:
                throw URLError(.badURL)
            }
        }

        let saved = try await context.repository.setFavorite(articleID: articleID, isFavorite: true, operationID: addID)
        let summaries = try await context.repository.favorites(locale: "zh-Hans", cursor: nil)
        let removed = try await context.repository.setFavorite(articleID: articleID, isFavorite: false, operationID: removeID)
        XCTAssertTrue(try XCTUnwrap(saved).isFavorite)
        XCTAssertEqual(summaries.items.first?.id, articleID)
        XCTAssertNil(removed)
    }

    func testSupportTicketCreateReadReplyCloseUseAuthenticatedOwner() async throws {
        let context = try makeContext()
        try await context.store.save(Self.session)
        let ticketID = try XCTUnwrap(UUID(uuidString: "d7000000-0000-4000-8000-000000000001"))
        let createID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000401"))
        let replyID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000402"))
        let closeID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000403"))
        ContentSupportURLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fictional-access")
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/support/tickets"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), createID.uuidString)
                return try Self.response(
                    request,
                    status: 201,
                    json: "{\"ticket\":\(Self.ticketJSON),\"first_message\":\(Self.messageJSON)}"
                )
            case ("GET", "/api/v1/support/tickets"):
                return try Self.response(
                    request,
                    status: 200,
                    json: "{\"items\":[\(Self.ticketJSON)],\"next_cursor\":null,\"has_more\":false}"
                )
            case ("GET", "/api/v1/support/tickets/\(ticketID.uuidString)"):
                return try Self.response(
                    request,
                    status: 200,
                    json: "{\"ticket\":\(Self.ticketJSON),\"messages\":[\(Self.messageJSON)]}"
                )
            case ("POST", "/api/v1/support/tickets/\(ticketID.uuidString)/messages"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), replyID.uuidString)
                return try Self.response(
                    request,
                    status: 201,
                    json: "{\"ticket\":\(Self.ticketJSON),\"message\":\(Self.messageJSON)}"
                )
            case ("POST", "/api/v1/support/tickets/\(ticketID.uuidString)/actions/close"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), closeID.uuidString)
                return try Self.response(request, status: 200, json: "{\"ticket\":\(Self.ticketJSON)}")
            default:
                throw URLError(.badURL)
            }
        }

        let created = try await context.repository.createTicket(
            category: "technical",
            subject: "Fictional issue",
            message: "fictional private message",
            operationID: createID
        )
        let page = try await context.repository.tickets(cursor: nil)
        let detail = try await context.repository.ticket(id: ticketID)
        let reply = try await context.repository.reply(
            ticketID: ticketID,
            message: "fictional reply",
            operationID: replyID
        )
        let closed = try await context.repository.close(ticketID: ticketID, operationID: closeID)
        XCTAssertEqual(created.ticket.id, ticketID)
        XCTAssertEqual(page.items.first?.id, ticketID)
        XCTAssertEqual(detail.messages.count, 1)
        XCTAssertEqual(reply.message.sequence, 1)
        XCTAssertEqual(closed.id, ticketID)
    }

    private func makeContext() throws -> (repository: BackendRepository, store: BackendSessionStore) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ContentSupportURLProtocolStub.self]
        let store = BackendSessionStore(credentials: ContentSupportMemoryCredentials())
        let client = MoveFitAPIClient(
            baseURL: try XCTUnwrap(URL(string: "https://backend.test")),
            urlSession: URLSession(configuration: configuration),
            sessionStore: store
        )
        return (BackendRepository(client: client), store)
    }

    private static let session = StoredBackendSession(
        accessToken: "fictional-access",
        refreshToken: "fictional-refresh",
        sessionID: UUID(),
        identifierKind: .email,
        identifier: "fictional@example.test"
    )

    private static let articleJSON = #"{"article_id":"a7000000-0000-4000-8000-000000000001","title":"Fictional article","summary":"Test only","category":"recovery","locale":"zh-Hans","body_markdown":"Test body","disclaimer":null,"revision":2,"published_at":"2026-08-08T09:00:00Z","updated_at":"2026-08-08T09:30:00Z"}"#
    private static let helpJSON = #"{"help_article_id":"b7000000-0000-4000-8000-000000000001","title":"Fictional help","category":"workouts","locale":"zh-Hans","body_markdown":"Test help","revision":1,"updated_at":"2026-08-08T08:15:00Z"}"#
    private static let favoriteSummaryJSON = #"{"article_id":"a7000000-0000-4000-8000-000000000001","title":"Fictional article","summary":"Test only","category":"recovery","locale":"zh-Hans","revision":2,"favorite_version":1,"favorite_updated_at":"2026-08-08T10:00:00Z"}"#
    private static let ticketJSON = #"{"ticket_id":"d7000000-0000-4000-8000-000000000001","category":"technical","subject":"Fictional issue","status":"open","version":1,"created_at":"2026-08-08T11:00:00Z","updated_at":"2026-08-08T11:00:00Z","closed_at":null}"#
    private static let messageJSON = #"{"message_id":"d7000000-0000-4000-8000-000000000002","sequence":1,"author_role":"user","body":"fictional private body","created_at":"2026-08-08T11:00:00Z"}"#

    private static func response(_ request: URLRequest, status: Int, json: String) throws -> (HTTPURLResponse, Data) {
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: XCTUnwrap(request.url),
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        )
        return (response, Data(json.utf8))
    }
}

private final class ContentSupportMemoryCredentials: CredentialStoring {
    private var values: [String: String] = [:]
    func save(token: String, account: String) throws { values[account] = token }
    func token(account: String) throws -> String? { values[account] }
    func delete(account: String) throws { values.removeValue(forKey: account) }
}

private final class ContentSupportURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
