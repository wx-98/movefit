import Foundation
import XCTest
@testable import MoveFit

final class RemoteChallengeNetworkingTests: XCTestCase {
    override func tearDown() {
        ChallengeURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testCatalogAndDetailUseLocaleAndCursor() async throws {
        let repository = try makeRepository()
        let challengeID = try XCTUnwrap(UUID(uuidString: "c7000000-0000-4000-8000-000000000001"))
        ChallengeURLProtocolStub.handler = { request in
            let query = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first(where: { $0.name == "locale" })?.value, "zh-Hans")
            if request.url?.path == "/api/v1/challenges" {
                XCTAssertEqual(query?.first(where: { $0.name == "cursor" })?.value, "opaque-cursor")
                return try Self.response(
                    request,
                    status: 200,
                    json: "{\"items\":[\(Self.challengeJSON)],\"next_cursor\":null,\"has_more\":false}"
                )
            }
            XCTAssertEqual(request.url?.path, "/api/v1/challenges/\(challengeID.uuidString)")
            return try Self.response(request, status: 200, json: Self.challengeJSON)
        }

        let page = try await repository.challenges(locale: "zh-Hans", cursor: "opaque-cursor")
        let detail = try await repository.challenge(id: challengeID, locale: "zh-Hans")
        XCTAssertEqual(page.items.first?.id, challengeID)
        XCTAssertFalse(page.hasMore)
        XCTAssertEqual(detail.goalUnit, "meters")
    }

    func testParticipationWritesUseIndependentIdempotencyKeysAndOwnerSession() async throws {
        let context = try makeContext()
        try await context.store.save(
            StoredBackendSession(
                accessToken: "fictional-access",
                refreshToken: "fictional-refresh",
                sessionID: UUID(),
                identifierKind: .email,
                identifier: "fictional@example.test"
            )
        )
        let challengeID = try XCTUnwrap(UUID(uuidString: "c7000000-0000-4000-8000-000000000001"))
        let joinID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000201"))
        let leaveID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000202"))
        ChallengeURLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fictional-access")
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/challenges/\(challengeID.uuidString)/participations"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), joinID.uuidString)
                return try Self.response(request, status: 201, json: Self.participationJSON)
            case ("GET", "/api/v1/me/challenge-participations"):
                return try Self.response(
                    request,
                    status: 200,
                    json: "{\"items\":[\(Self.participationJSON)],\"next_cursor\":null,\"has_more\":false}"
                )
            case ("DELETE", "/api/v1/challenges/\(challengeID.uuidString)/participations/current"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), leaveID.uuidString)
                return try Self.response(request, status: 204, json: "")
            default:
                throw URLError(.badURL)
            }
        }

        let joined = try await context.repository.join(
            challengeID: challengeID,
            locale: "zh-Hans",
            operationID: joinID
        )
        let mine = try await context.repository.participations(cursor: nil)
        try await context.repository.leave(challengeID: challengeID, operationID: leaveID)
        XCTAssertEqual(joined.challengeID, challengeID)
        XCTAssertEqual(mine.items.first?.id, joined.id)
    }

    func testLeaderboardExposesOnlyAnonymousAlias() async throws {
        let repository = try makeRepository()
        let challengeID = try XCTUnwrap(UUID(uuidString: "c7000000-0000-4000-8000-000000000001"))
        ChallengeURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/challenges/\(challengeID.uuidString)/leaderboard")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return try Self.response(
                request,
                status: 200,
                json: #"{"snapshot_generated_at":"2026-08-08T12:00:00Z","items":[{"rank":1,"display_alias":"Mover-ABCDEF123456","progress_value":8200,"goal_unit":"meters","is_current_user":false}],"next_cursor":null,"has_more":false}"#
            )
        }

        let leaderboard = try await repository.leaderboard(challengeID: challengeID, cursor: nil)
        XCTAssertEqual(leaderboard.entries.first?.displayAlias, "Mover-ABCDEF123456")
    }

    private func makeRepository() throws -> BackendRepository {
        try makeContext().repository
    }

    private func makeContext() throws -> (repository: BackendRepository, store: BackendSessionStore) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChallengeURLProtocolStub.self]
        let store = BackendSessionStore(credentials: ChallengeMemoryCredentials())
        let client = MoveFitAPIClient(
            baseURL: try XCTUnwrap(URL(string: "https://backend.test")),
            urlSession: URLSession(configuration: configuration),
            sessionStore: store
        )
        return (BackendRepository(client: client), store)
    }

    private static let challengeJSON = #"{"challenge_id":"c7000000-0000-4000-8000-000000000001","title":"Fictional challenge","summary":"Test only","metric":"distance","goal_value":10000,"goal_unit":"meters","starts_at":"2026-08-01T00:00:00Z","ends_at":"2026-08-31T00:00:00Z","enrollment_opens_at":"2026-07-25T00:00:00Z","enrollment_closes_at":"2026-08-15T00:00:00Z","exit_closes_at":null,"eligible_workout_types":["running"],"eligible_workout_sources":["movefit_recorded"],"rule_version":1}"#

    private static let participationJSON = #"{"participation_id":"c7000000-0000-4000-8000-000000000002","challenge_id":"c7000000-0000-4000-8000-000000000001","status":"active","progress_value":8200,"goal_value":10000,"goal_unit":"meters","is_complete":false,"calculated_at":"2026-08-08T12:00:00Z"}"#

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

private final class ChallengeMemoryCredentials: CredentialStoring {
    private var values: [String: String] = [:]
    func save(token: String, account: String) throws { values[account] = token }
    func token(account: String) throws -> String? { values[account] }
    func delete(account: String) throws { values.removeValue(forKey: account) }
}

private final class ChallengeURLProtocolStub: URLProtocol {
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
