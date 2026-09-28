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

    func testRemoteTrainingCatalogReadsCursorPagesAndMapsPublishedPlans() async throws {
        let context = try makeContext()
        var requestedCursors: [String?] = []
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/training-plans")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let query = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems
            XCTAssertEqual(query?.first(where: { $0.name == "locale" })?.value, "zh-Hans")
            XCTAssertEqual(query?.first(where: { $0.name == "limit" })?.value, "50")
            let cursor = query?.first(where: { $0.name == "cursor" })?.value
            requestedCursors.append(cursor)
            if cursor == nil {
                return try Self.response(
                    for: request,
                    status: 200,
                    json: Self.trainingPlanPage(id: "00000000-0000-0000-0000-000000000101", nextCursor: "page-two")
                )
            }
            XCTAssertEqual(cursor, "page-two")
            return try Self.response(
                for: request,
                status: 200,
                json: Self.trainingPlanPage(id: "00000000-0000-0000-0000-000000000102", nextCursor: nil)
            )
        }

        let result = try await RemoteTrainingCatalogRepository(client: context.repository.client).plans(locale: "zh-Hans")

        XCTAssertEqual(requestedCursors.count, 2)
        XCTAssertEqual(requestedCursors[0], nil)
        XCTAssertEqual(requestedCursors[1], "page-two")
        XCTAssertEqual(result.source, .remote)
        XCTAssertEqual(result.plans.map(\.id), [
            "00000000-0000-0000-0000-000000000101",
            "00000000-0000-0000-0000-000000000102"
        ])
        XCTAssertEqual(result.plans[0].title, "基础跑步")
        XCTAssertEqual(result.plans[0].steps.map(\.durationMinutes), [5, 15])
        XCTAssertEqual(result.plans[0].safetyNotes, ["循序渐进"])
    }

    func testRemoteTrainingCatalogKeepsValidEmptyPublicationEmpty() async throws {
        let context = try makeContext()
        URLProtocolStub.handler = { request in
            try Self.response(for: request, status: 200, json: #"{"items":[],"next_cursor":null,"has_more":false}"#)
        }

        let result = try await RemoteTrainingCatalogRepository(client: context.repository.client).plans(locale: "en")

        XCTAssertEqual(result.plans, [])
        XCTAssertEqual(result.source, .remote)
    }

    func testRemoteTrainingCatalogRejectsUnknownTypeAndCursorLoop() async throws {
        let context = try makeContext()
        URLProtocolStub.handler = { request in
            let invalid = Self.trainingPlanPage(
                id: "00000000-0000-0000-0000-000000000101", nextCursor: nil
            ).replacingOccurrences(of: #""workout_type":"running""#, with: #""workout_type":"unknown""#)
            return try Self.response(for: request, status: 200, json: invalid)
        }
        do {
            _ = try await RemoteTrainingCatalogRepository(client: context.repository.client).plans(locale: "zh-Hans")
            XCTFail("未知运动类型必须失败")
        } catch {
            XCTAssertEqual(error as? BackendError, .invalidResponse)
        }

        URLProtocolStub.handler = { request in
            try Self.response(
                for: request,
                status: 200,
                json: Self.trainingPlanPage(id: "00000000-0000-0000-0000-000000000101", nextCursor: "same")
            )
        }
        do {
            _ = try await RemoteTrainingCatalogRepository(client: context.repository.client).plans(locale: "zh-Hans")
            XCTFail("重复 cursor 必须失败")
        } catch {
            XCTAssertEqual(error as? BackendError, .invalidResponse)
        }
    }

    func testTrainingCatalogFallbackDiscardsPartialRemotePage() async throws {
        let context = try makeContext()
        URLProtocolStub.handler = { request in
            let cursor = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
                .queryItems?.first(where: { $0.name == "cursor" })?.value
            if cursor == nil {
                return try Self.response(
                    for: request,
                    status: 200,
                    json: Self.trainingPlanPage(id: "00000000-0000-0000-0000-000000000101", nextCursor: "next")
                )
            }
            return try Self.response(for: request, status: 503, json: #"{"code":"temporarily_unavailable"}"#)
        }
        let repository = FallbackTrainingCatalogRepository(
            remote: RemoteTrainingCatalogRepository(client: context.repository.client),
            fallback: BundledTrainingCatalog()
        )

        let result = try await repository.plans(locale: "zh-Hans")

        XCTAssertEqual(result.source, .bundledFallback(reason: .unavailable))
        XCTAssertFalse(result.plans.isEmpty)
        XCTAssertFalse(result.plans.contains { $0.id == "00000000-0000-0000-0000-000000000101" })
    }

    func testRemoteTrainingCatalogRejectsWhitespaceStepTitle() async throws {
        let context = try makeContext()
        URLProtocolStub.handler = { request in
            let invalid = Self.trainingPlanPage(
                id: "00000000-0000-0000-0000-000000000101", nextCursor: nil
            ).replacingOccurrences(of: #""title":"热身""#, with: #""title":"   ""#)
            return try Self.response(for: request, status: 200, json: invalid)
        }

        do {
            _ = try await RemoteTrainingCatalogRepository(client: context.repository.client).plans(locale: "zh-Hans")
            XCTFail("纯空白步骤标题必须拒绝")
        } catch {
            XCTAssertEqual(error as? BackendError, .invalidResponse)
        }
    }

    func testRemoteTrainingCatalogRejectsUnboundedStepDurationWithoutOverflow() async throws {
        let context = try makeContext()
        URLProtocolStub.handler = { request in
            let invalid = Self.trainingPlanPage(
                id: "00000000-0000-0000-0000-000000000101", nextCursor: nil
            ).replacingOccurrences(
                of: #""duration_minutes":5"#,
                with: #""duration_minutes":9223372036854775807"#
            )
            return try Self.response(for: request, status: 200, json: invalid)
        }

        do {
            _ = try await RemoteTrainingCatalogRepository(client: context.repository.client).plans(locale: "zh-Hans")
            XCTFail("越界步骤时长必须拒绝")
        } catch {
            XCTAssertEqual(error as? BackendError, .invalidResponse)
        }
    }

    private static func trainingPlanPage(id: String, nextCursor: String?) -> String {
        let cursor = nextCursor.map { #""\#($0)""# } ?? "null"
        let hasMore = nextCursor == nil ? "false" : "true"
        return #"{"items":[{"training_plan_id":"\#(id)","slug":"run-basics","workout_type":"running","difficulty":"beginner","locale":"zh-Hans","revision":1,"title":"基础跑步","subtitle":"耐力训练","duration_minutes":20,"goal":"完成训练","suitable_for":"初学者","steps":[{"order":1,"title":"热身","detail":"慢走","duration_minutes":5},{"order":2,"title":"跑步","detail":"慢跑","duration_minutes":15}],"safety_notes":["循序渐进"],"published_at":"2026-09-01T00:00:00Z","updated_at":"2026-09-01T00:00:00Z"}],"next_cursor":\#(cursor),"has_more":\#(hasMore)}"#
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
