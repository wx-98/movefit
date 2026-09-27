import XCTest
@testable import MoveFit

final class RegistrationVerificationNetworkingTests: XCTestCase {
    override func tearDown() {
        RegistrationURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testChallengeRequestUsesPublicSnakeCaseContract() async throws {
        let repository = try makeRepository()
        RegistrationURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/verification-challenges")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let body = try Self.requestBody(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
            XCTAssertEqual(json, [
                "identifier": "+8613800000000",
                "channel": "phone",
                "device_id": "installation-test-id"
            ])
            return try Self.response(
                for: request,
                status: 202,
                json: #"{"challenge_id":"00000000-0000-0000-0000-000000000601"}"#
            )
        }

        let challengeID = try await repository.requestRegistrationChallenge(
            identifier: RegistrationIdentifier(kind: .phone, rawValue: "+8613800000000"),
            deviceID: "installation-test-id"
        )

        XCTAssertEqual(
            challengeID,
            UUID(uuidString: "00000000-0000-0000-0000-000000000601")
        )
    }

    func testChallengeConfirmationUsesOpaqueIDAndReturnsProof() async throws {
        let repository = try makeRepository()
        let challengeID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000602")
        )
        RegistrationURLProtocolStub.handler = { request in
            XCTAssertEqual(
                request.url?.path,
                "/api/v1/auth/verification-challenges/\(challengeID.uuidString)/verify"
            )
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let body = try Self.requestBody(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
            XCTAssertEqual(json, [
                "code": "123456",
                "device_id": "installation-test-id"
            ])
            return try Self.response(
                for: request,
                status: 200,
                json: #"{"verification_proof":"proof-from-test-fake"}"#
            )
        }

        let proof = try await repository.confirmRegistrationChallenge(
            challengeID: challengeID,
            code: RegistrationVerificationCode("123456"),
            deviceID: "installation-test-id"
        )

        XCTAssertEqual(proof, "proof-from-test-fake")
    }

    func testFinalRegistrationSendsProofOnlyInRegisterPayload() async throws {
        let repository = try makeRepository()
        let challengeID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000603")
        )
        var paths: [String] = []
        RegistrationURLProtocolStub.handler = { request in
            let path = try XCTUnwrap(request.url?.path)
            paths.append(path)
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            if path.hasSuffix("/verify") {
                return try Self.response(
                    for: request,
                    status: 200,
                    json: #"{"verification_proof":"proof-from-test-fake"}"#
                )
            }
            XCTAssertEqual(path, "/api/v1/auth/register")
            let body = try Self.requestBody(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
            XCTAssertEqual(json, [
                "identifier_kind": "email",
                "identifier": "tester@example.com",
                "password": "fictional-password-123",
                "verification_proof": "proof-from-test-fake"
            ])
            return try Self.response(
                for: request,
                status: 201,
                json: #"{"user_id":"00000000-0000-0000-0000-000000000604","identifier_kind":"email"}"#
            )
        }
        let context = RegistrationChallengeContext(
            identifier: try RegistrationIdentifier(kind: .email, rawValue: "tester@example.com"),
            challengeID: challengeID,
            deviceID: "installation-test-id",
            cooldownUntil: Date()
        )
        let useCase = CompleteVerifiedRegistrationUseCase(
            verificationProvider: repository,
            authenticationProvider: repository
        )

        _ = try await useCase.execute(
            context: context,
            code: "123456",
            password: "fictional-password-123"
        )

        XCTAssertEqual(paths, [
            "/api/v1/auth/verification-challenges/\(challengeID.uuidString)/verify",
            "/api/v1/auth/register"
        ])
    }

    func testRateLimitUsesValidRetryAfterSeconds() async throws {
        let repository = try makeRepository()
        RegistrationURLProtocolStub.handler = { request in
            try Self.response(
                for: request,
                status: 429,
                json: #"{"code":"auth_rate_limited","detail":"provider detail must not be shown"}"#,
                headers: ["Retry-After": "120"]
            )
        }

        do {
            _ = try await repository.requestRegistrationChallenge(
                identifier: RegistrationIdentifier(kind: .email, rawValue: "tester@example.com"),
                deviceID: "installation-test-id"
            )
            XCTFail("Expected rate limit error")
        } catch let error as RegistrationVerificationError {
            XCTAssertEqual(error, .rateLimited(retryAfterSeconds: 120))
        }
    }

    func testRateLimitUsesConservativeDefaultWhenRetryAfterIsMissingOrInvalid() async throws {
        for value in [nil, "not-a-number", "0", "999999"] as [String?] {
            let repository = try makeRepository()
            RegistrationURLProtocolStub.handler = { request in
                var headers: [String: String] = [:]
                if let value { headers["Retry-After"] = value }
                return try Self.response(
                    for: request,
                    status: 429,
                    json: #"{"code":"auth_rate_limited"}"#,
                    headers: headers
                )
            }

            do {
                _ = try await repository.requestRegistrationChallenge(
                    identifier: RegistrationIdentifier(kind: .email, rawValue: "tester@example.com"),
                    deviceID: "installation-test-id"
                )
                XCTFail("Expected rate limit error")
            } catch let error as RegistrationVerificationError {
                XCTAssertEqual(error, .rateLimited(retryAfterSeconds: 60))
            }
        }
    }

    func testStableVerificationCodesMapToTypedCredentialSafeErrors() async throws {
        let cases: [(Int, String, RegistrationVerificationError)] = [
            (503, "verification_delivery_unavailable", .deliveryUnavailable),
            (400, "verification_code_invalid", .invalidCode),
            (400, "registration_verification_invalid", .invalidProof)
        ]
        for (status, code, expected) in cases {
            let repository = try makeRepository()
            RegistrationURLProtocolStub.handler = { request in
                try Self.response(
                    for: request,
                    status: status,
                    json: "{\"code\":\"\(code)\",\"detail\":\"raw provider diagnostic\"}"
                )
            }

            do {
                if code == "registration_verification_invalid" {
                    try await repository.register(
                        kind: .email,
                        identifier: "tester@example.com",
                        password: "fictional-password-123",
                        verificationProof: "proof-from-test-fake"
                    )
                } else if code == "verification_code_invalid" {
                    _ = try await repository.confirmRegistrationChallenge(
                        challengeID: UUID(),
                        code: RegistrationVerificationCode("123456"),
                        deviceID: "installation-test-id"
                    )
                } else {
                    _ = try await repository.requestRegistrationChallenge(
                        identifier: RegistrationIdentifier(
                            kind: .email,
                            rawValue: "tester@example.com"
                        ),
                        deviceID: "installation-test-id"
                    )
                }
                XCTFail("Expected typed verification error")
            } catch let error as RegistrationVerificationError {
                XCTAssertEqual(error, expected)
                XCTAssertFalse(error.localizedDescription.contains("provider diagnostic"))
            }
        }
    }

    func testDeliveryUnavailableDoesNotBlockPasswordLoginOrSessionRestore() async throws {
        let credentials = RegistrationMemoryCredentialStore()
        let repository = try makeRepository(credentials: credentials)
        var requestedPaths: [String] = []
        RegistrationURLProtocolStub.handler = { request in
            let path = try XCTUnwrap(request.url?.path)
            requestedPaths.append(path)
            switch path {
            case "/api/v1/auth/verification-challenges":
                return try Self.response(
                    for: request,
                    status: 503,
                    json: #"{"code":"verification_delivery_unavailable","detail":"private provider diagnostic"}"#
                )
            case "/api/v1/auth/login/password":
                return try Self.response(
                    for: request,
                    status: 200,
                    json: #"{"access_token":"fictional-access","refresh_token":"fictional-refresh","token_type":"Bearer"}"#
                )
            default:
                throw URLError(.badURL)
            }
        }

        do {
            _ = try await repository.requestRegistrationChallenge(
                identifier: RegistrationIdentifier(kind: .email, rawValue: "tester@example.com"),
                deviceID: "installation-test-id"
            )
            XCTFail("Expected delivery unavailable")
        } catch let error as RegistrationVerificationError {
            XCTAssertEqual(error, .deliveryUnavailable)
            XCTAssertFalse(error.localizedDescription.contains("provider diagnostic"))
        }

        let signedIn = try await repository.signIn(
            kind: .email,
            identifier: "login@example.com",
            password: "fictional-password-123"
        )
        let restored = try await repository.restoreSession()

        XCTAssertEqual(signedIn.displayName, "login@example.com")
        XCTAssertEqual(restored, signedIn)
        XCTAssertEqual(requestedPaths, [
            "/api/v1/auth/verification-challenges",
            "/api/v1/auth/login/password"
        ])
    }

    private func makeRepository(
        credentials: CredentialStoring = RegistrationMemoryCredentialStore()
    ) throws -> BackendRepository {
        let baseURL = try XCTUnwrap(URL(string: "https://backend.test"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RegistrationURLProtocolStub.self]
        let client = MoveFitAPIClient(
            baseURL: baseURL,
            urlSession: URLSession(configuration: configuration),
            sessionStore: BackendSessionStore(credentials: credentials)
        )
        return BackendRepository(client: client)
    }

    private static func response(
        for request: URLRequest,
        status: Int,
        json: String,
        headers: [String: String] = [:]
    ) throws -> (HTTPURLResponse, Data) {
        var responseHeaders = headers
        responseHeaders["Content-Type"] = "application/json"
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: XCTUnwrap(request.url),
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: responseHeaders
            )
        )
        return (response, Data(json.utf8))
    }

    private static func requestBody(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count == 0 {
                return body
            }
            if count < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeContentData)
            }
            body.append(buffer, count: count)
        }
    }
}

private final class RegistrationMemoryCredentialStore: CredentialStoring {
    private var values: [String: String] = [:]

    func save(token: String, account: String) throws {
        values[account] = token
    }

    func token(account: String) throws -> String? {
        values[account]
    }

    func delete(account: String) throws {
        values.removeValue(forKey: account)
    }
}

private final class RegistrationURLProtocolStub: URLProtocol {
    private static let handlerLock = NSLock()
    private static var storedHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        get {
            handlerLock.lock()
            defer { handlerLock.unlock() }
            return storedHandler
        }
        set {
            handlerLock.lock()
            storedHandler = newValue
            handlerLock.unlock()
        }
    }

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
