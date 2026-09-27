import Foundation
import XCTest
@testable import MoveFit

final class BackendIntegrationTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testClientConfigurationUsesExpectedEndpointAndMapsResponse() async throws {
        let context = try makeContext()
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/client-config")
            let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "platform" })?.value, "ios")
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "app_version" })?.value, "1.0.0")
            return try Self.response(
                for: request,
                status: 200,
                json: #"{"schema_version":"1","revision":9,"config":{"feature_enabled":false,"sync_interval_seconds":60}}"#
            )
        }

        let configuration = try await context.repository.configuration(appVersion: "1.0.0")

        XCTAssertEqual(configuration.schemaVersion, "1")
        XCTAssertEqual(configuration.revision, 9)
        XCTAssertEqual(configuration.featureEnabled, false)
        XCTAssertEqual(configuration.syncIntervalSeconds, 60)
    }

    func testExpiredAccessTokenRefreshesOnceAndRetriesProtectedRequest() async throws {
        let context = try makeContext()
        try await context.store.save(
            StoredBackendSession(
                accessToken: "old-access",
                refreshToken: "old-refresh",
                sessionID: UUID(),
                identifierKind: .email,
                identifier: "tester@example.com"
            )
        )
        let lock = NSLock()
        var profileRequestCount = 0
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/v1/auth/token/refresh":
                return try Self.response(
                    for: request,
                    status: 200,
                    json: #"{"access_token":"new-access","refresh_token":"new-refresh","token_type":"Bearer"}"#
                )
            case "/api/v1/me":
                lock.lock()
                profileRequestCount += 1
                let count = profileRequestCount
                lock.unlock()
                if count == 1 {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer old-access")
                    return try Self.response(
                        for: request,
                        status: 401,
                        json: #"{"code":"authentication_required","detail":"expired"}"#
                    )
                }
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer new-access")
                return try Self.response(
                    for: request,
                    status: 200,
                    json: #"{"nickname":"测试用户","current_height_centimeters":170,"current_weight_kilograms":60,"current_body_fat_percentage":20,"version":2}"#
                )
            default:
                throw URLError(.badURL)
            }
        }

        let profile = try await context.repository.currentProfile()
        let stored = try await context.store.session()

        XCTAssertEqual(profile.nickname, "测试用户")
        XCTAssertEqual(profile.version, 2)
        XCTAssertEqual(profileRequestCount, 2)
        XCTAssertEqual(stored?.accessToken, "new-access")
        XCTAssertEqual(stored?.refreshToken, "new-refresh")
    }

    func testConcurrentUnauthorizedRequestsShareOneTokenRefresh() async throws {
        let context = try makeContext()
        try await context.store.save(
            StoredBackendSession(
                accessToken: "old-access",
                refreshToken: "old-refresh",
                sessionID: UUID(),
                identifierKind: .email,
                identifier: "tester@example.com"
            )
        )
        let lock = NSLock()
        var refreshCount = 0
        URLProtocolStub.handler = { request in
            if request.url?.path == "/api/v1/auth/token/refresh" {
                lock.lock()
                refreshCount += 1
                lock.unlock()
                Thread.sleep(forTimeInterval: 0.05)
                return try Self.response(
                    for: request,
                    status: 200,
                    json: #"{"access_token":"new-access","refresh_token":"new-refresh","token_type":"Bearer"}"#
                )
            }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer old-access" {
                return try Self.response(
                    for: request,
                    status: 401,
                    json: #"{"code":"authentication_required","detail":"expired"}"#
                )
            }
            return try Self.response(
                for: request,
                status: 200,
                json: #"{"nickname":"并发测试","current_height_centimeters":170,"current_weight_kilograms":60,"current_body_fat_percentage":20,"version":2}"#
            )
        }

        async let first = context.repository.currentProfile()
        async let second = context.repository.currentProfile()
        let profiles = try await [first, second]

        XCTAssertEqual(profiles.map(\.nickname), ["并发测试", "并发测试"])
        XCTAssertEqual(refreshCount, 1)
    }

    func testWorkoutRepositoryReadsEveryCursorPageAndMapsUnits() async throws {
        let context = try makeContext()
        try await context.store.save(
            StoredBackendSession(
                accessToken: "access",
                refreshToken: "refresh",
                sessionID: UUID(),
                identifierKind: .phone,
                identifier: "+8613800000000"
            )
        )
        URLProtocolStub.handler = { request in
            let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            let cursor = components?.queryItems?.first(where: { $0.name == "cursor" })?.value
            if cursor == nil {
                return try Self.response(
                    for: request,
                    status: 200,
                    json: #"{"items":[{"id":"00000000-0000-0000-0000-000000000101","type":"running","source":"manual","started_at":"2026-08-08T01:00:00.000Z","duration_seconds":600,"distance_meters":2000,"energy_kilocalories":120,"deleted_at":null}],"next_cursor":"next-page","has_more":true}"#
                )
            }
            XCTAssertEqual(cursor, "next-page")
            return try Self.response(
                for: request,
                status: 200,
                json: #"{"items":[{"id":"00000000-0000-0000-0000-000000000102","type":"yoga","source":"healthkit_import","started_at":"2026-08-07T01:00:00Z","duration_seconds":1800,"distance_meters":null,"energy_kilocalories":80,"deleted_at":null}],"next_cursor":null,"has_more":false}"#
            )
        }

        let workouts = try await context.repository.workouts()

        XCTAssertEqual(workouts.count, 2)
        XCTAssertEqual(workouts[0].distance?.converted(to: .meters).value, 2_000)
        XCTAssertEqual(workouts[0].source, .moveFit)
        XCTAssertEqual(workouts[1].source, .appleHealth)
    }

    func testRemoteExerciseCatalogUsesRuntimePageSizeParameterAndMapsImages() async throws {
        let session = makeURLSession()
        guard let baseURL = URL(string: "http://actions.test") else {
            return XCTFail("测试 URL 无效")
        }
        URLProtocolStub.handler = { request in
            let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "page_size" })?.value, "25")
            XCTAssertNil(components?.queryItems?.first(where: { $0.name == "pageSize" }))
            return try Self.response(
                for: request,
                status: 200,
                json: #"{"catalogVersion":"2026-08-08.3","page":0,"pageSize":25,"hasMore":false,"items":[{"id":"squat","nameZhHans":"深蹲","originalName":"Squat","difficulty":"beginner","equipment":"body only","primaryMuscles":["quadriceps"],"secondaryMuscles":[],"instructionsZhHans":["下蹲"],"safetyNotesZhHans":["疼痛时停止"],"images":["https://example.com/squat.jpg"]}]}"#
            )
        }
        let repository = RemoteExerciseCatalogRepository(baseURL: baseURL, urlSession: session)

        let page = try await repository.exercises(query: ExerciseCatalogQuery(), page: 0, pageSize: 25)

        XCTAssertEqual(page.sourceVersion, "2026-08-08.3")
        XCTAssertEqual(page.exercises.first?.difficulty, .beginner)
        XCTAssertEqual(page.exercises.first?.imageURLs.first?.absoluteString, "https://example.com/squat.jpg")
        XCTAssertEqual(page.source, .remote)
    }

    func testExerciseCatalogFallsBackToBundledDataWhenRemoteIsOffline() async throws {
        let session = makeURLSession()
        guard let baseURL = URL(string: "http://actions.test") else {
            return XCTFail("测试 URL 无效")
        }
        URLProtocolStub.handler = { _ in throw URLError(.notConnectedToInternet) }
        let repository = FallbackExerciseCatalogRepository(
            remote: RemoteExerciseCatalogRepository(baseURL: baseURL, urlSession: session)
        )

        let page = try await repository.exercises(query: ExerciseCatalogQuery(), page: 0, pageSize: 20)

        XCTAssertFalse(page.exercises.isEmpty)
        guard case .bundledFallback = page.source else {
            return XCTFail("远程失败时应明确标识内置降级")
        }
    }

    private func makeContext() throws -> (
        repository: BackendRepository,
        store: BackendSessionStore
    ) {
        guard let baseURL = URL(string: "http://backend.test") else {
            throw URLError(.badURL)
        }
        let store = BackendSessionStore(credentials: MemoryCredentialStore())
        let client = MoveFitAPIClient(
            baseURL: baseURL,
            urlSession: makeURLSession(),
            sessionStore: store
        )
        return (BackendRepository(client: client), store)
    }

    private func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private static func response(
        for request: URLRequest,
        status: Int,
        json: String
    ) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: status,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": "application/json"]
              ) else {
            throw URLError(.badServerResponse)
        }
        return (response, Data(json.utf8))
    }
}

private final class MemoryCredentialStore: CredentialStoring {
    private var values: [String: String] = [:]
    private let lock = NSLock()

    func save(token: String, account: String) throws {
        lock.lock()
        values[account] = token
        lock.unlock()
    }

    func token(account: String) throws -> String? {
        lock.lock()
        let value = values[account]
        lock.unlock()
        return value
    }

    func delete(account: String) throws {
        lock.lock()
        values.removeValue(forKey: account)
        lock.unlock()
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
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
