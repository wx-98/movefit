import Foundation
import XCTest
@testable import MoveFit

final class SocialIdentityNetworkingTests: XCTestCase {
    override func tearDown() {
        SocialURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testAppleLoginStoresSocialSessionWithoutPasswordIdentifier() async throws {
        let context = try makeContext()
        SocialURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/login/apple")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let payload = try Self.payload(request)
            XCTAssertEqual(payload["authorization_code"], "fictional-code")
            XCTAssertEqual(payload["nonce"], "fictional-nonce")
            XCTAssertEqual(payload["device_id"], "fictional-device")
            return try Self.response(
                request,
                status: 200,
                json: #"{"access_token":"fictional-access","refresh_token":"fictional-refresh","token_type":"Bearer"}"#
            )
        }

        let session = try await context.repository.signIn(
            provider: .apple,
            authorization: SocialAuthorization(
                authorizationCode: "fictional-code",
                nonce: "fictional-nonce",
                deviceID: "fictional-device"
            )
        )

        let restored = try await context.repository.restoreSession()
        let stored = try await context.store.session()
        XCTAssertEqual(session.method, .apple)
        XCTAssertEqual(restored, session)
        XCTAssertEqual(stored?.socialProvider, .apple)
        XCTAssertNil(stored?.identifierKind)
    }

    func testWechatLoginUsesProviderCodeWithoutNonce() async throws {
        let context = try makeContext()
        SocialURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/login/wechat")
            let payload = try Self.payload(request)
            XCTAssertEqual(payload["authorization_code"], "fictional-wechat-code")
            XCTAssertNil(payload["nonce"])
            return try Self.response(
                request,
                status: 200,
                json: #"{"access_token":"fictional-access","refresh_token":"fictional-refresh","token_type":"Bearer"}"#
            )
        }

        let session = try await context.repository.signIn(
            provider: .wechat,
            authorization: SocialAuthorization(
                authorizationCode: "fictional-wechat-code",
                nonce: nil,
                deviceID: "fictional-device"
            )
        )
        XCTAssertEqual(session.method, .wechat)
    }

    func testLinkAndUnlinkUseBearerAndStableOperationKey() async throws {
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
        let linkOperationID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let unlinkOperationID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000102"))
        var linkCalls = 0
        SocialURLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fictional-access")
            if request.httpMethod == "POST" {
                linkCalls += 1
                XCTAssertEqual(request.url?.path, "/api/v1/auth/identities/wechat/link")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), linkOperationID.uuidString)
                return try Self.response(
                    request,
                    status: 200,
                    json: #"{"provider":"wechat","masked_hint":"wx***","linked_at":"2026-08-08T08:00:00Z"}"#
                )
            }
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/api/v1/auth/identities/wechat")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), unlinkOperationID.uuidString)
            return try Self.response(request, status: 204, json: "")
        }

        let linked = try await context.repository.link(
            provider: .wechat,
            authorization: SocialAuthorization(
                authorizationCode: "fictional-code",
                nonce: nil,
                deviceID: "fictional-device"
            ),
            operationID: linkOperationID
        )
        let replayed = try await context.repository.link(
            provider: .wechat,
            authorization: SocialAuthorization(
                authorizationCode: "fictional-code",
                nonce: nil,
                deviceID: "fictional-device"
            ),
            operationID: linkOperationID
        )
        try await context.repository.unlink(provider: .wechat, operationID: unlinkOperationID)
        XCTAssertEqual(linked.provider, .wechat)
        XCTAssertEqual(replayed, linked)
        XCTAssertEqual(linkCalls, 2)
    }

    func testGoogleLinkAndIdentityListDoNotReplaceSession() async throws {
        let context = try makeContext()
        let original = StoredBackendSession(
            accessToken: "original-access",
            refreshToken: "original-refresh",
            sessionID: UUID(),
            identifierKind: .email,
            identifier: "fictional@example.test"
        )
        try await context.store.save(original)
        let operationID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000103"))
        SocialURLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer original-access")
            if request.httpMethod == "POST" {
                XCTAssertEqual(request.url?.path, "/api/v1/auth/identities/google/link")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), operationID.uuidString)
                let payload = try Self.payload(request)
                XCTAssertEqual(payload["state"], "fictional-state")
                XCTAssertEqual(payload["code_verifier"], String(repeating: "a", count: 43))
                return try Self.response(
                    request,
                    status: 200,
                    json: #"{"provider":"google","masked_hint":"g***@example.test","linked_at":"2026-08-08T08:00:00Z"}"#
                )
            }
            XCTAssertEqual(request.url?.path, "/api/v1/auth/identities")
            return try Self.response(
                request,
                status: 200,
                json: #"{"items":[{"provider":"google","masked_hint":"g***@example.test","linked_at":"2026-08-08T08:00:00Z"}]}"#
            )
        }
        let redirectURI = try XCTUnwrap(URL(string: "com.movefit.mobile:/oauth2redirect"))
        let linked = try await context.repository.linkGoogle(
            GoogleAuthorizationCompletion(
                authorizationCode: "fictional-code",
                state: "fictional-state",
                codeVerifier: String(repeating: "a", count: 43),
                redirectURI: redirectURI,
                deviceID: "fictional-device"
            ),
            operationID: operationID
        )
        let identities = try await context.repository.identities()
        let stored = try await context.store.session()
        XCTAssertEqual(linked.provider, .google)
        XCTAssertEqual(identities.map(\.provider), [.google])
        XCTAssertEqual(stored, original)
    }

    func testGoogleHandoffAndCompletionPreserveExistingSessionOnFailure() async throws {
        let context = try makeContext()
        let original = StoredBackendSession(
            accessToken: "original-access",
            refreshToken: "original-refresh",
            sessionID: UUID(),
            identifierKind: .email,
            identifier: "fictional@example.test"
        )
        try await context.store.save(original)
        SocialURLProtocolStub.handler = { request in
            if request.url?.path == "/api/v1/auth/login/google/authorization" {
                let payload = try Self.payload(request)
                XCTAssertEqual(payload["code_challenge"], String(repeating: "a", count: 43))
                return try Self.response(
                    request,
                    status: 200,
                    json: #"{"authorization_url":"https://accounts.google.test/auth","state":"fictional-state","expires_at":"2026-08-09T10:05:00Z"}"#
                )
            }
            XCTAssertEqual(request.url?.path, "/api/v1/auth/login/google")
            return try Self.response(
                request,
                status: 400,
                json: #"{"code":"google_authorization_invalid","detail":"private provider diagnostic"}"#
            )
        }

        let redirectURI = try XCTUnwrap(URL(string: "com.movefit.mobile:/oauth2redirect"))
        let handoff = try await context.repository.beginGoogleAuthorization(
            redirectURI: redirectURI,
            codeChallenge: String(repeating: "a", count: 43),
            deviceID: "fictional-device"
        )
        XCTAssertEqual(handoff.state, "fictional-state")
        do {
            _ = try await context.repository.completeGoogleSignIn(
                GoogleAuthorizationCompletion(
                    authorizationCode: "fictional-code",
                    state: handoff.state,
                    codeVerifier: String(repeating: "b", count: 43),
                    redirectURI: redirectURI,
                    deviceID: "fictional-device"
                )
            )
            XCTFail("Expected Google authorization failure")
        } catch let error as RemoteServiceError {
            XCTAssertEqual(error, .server(status: 400, code: "google_authorization_invalid", retryAfterSeconds: nil))
        }
        let stored = try await context.store.session()
        XCTAssertEqual(stored, original)
    }

    private func makeContext() throws -> (repository: BackendRepository, store: BackendSessionStore) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SocialURLProtocolStub.self]
        let store = BackendSessionStore(credentials: SocialMemoryCredentials())
        let client = MoveFitAPIClient(
            baseURL: try XCTUnwrap(URL(string: "https://backend.test")),
            urlSession: URLSession(configuration: configuration),
            sessionStore: store
        )
        return (BackendRepository(client: client), store)
    }

    private static func payload(_ request: URLRequest) throws -> [String: String] {
        let body: Data
        if let direct = request.httpBody {
            body = direct
        } else {
            let stream = try XCTUnwrap(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var collected = Data()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while true {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count == 0 { break }
                if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeContentData) }
                collected.append(buffer, count: count)
            }
            body = collected
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
    }

    private static func response(
        _ request: URLRequest,
        status: Int,
        json: String
    ) throws -> (HTTPURLResponse, Data) {
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

private final class SocialMemoryCredentials: CredentialStoring {
    private var values: [String: String] = [:]

    func save(token: String, account: String) throws { values[account] = token }
    func token(account: String) throws -> String? { values[account] }
    func delete(account: String) throws { values.removeValue(forKey: account) }
}

private final class SocialURLProtocolStub: URLProtocol {
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
