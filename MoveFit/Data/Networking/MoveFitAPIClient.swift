import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

struct BackendRequest {
    let path: String
    var method = HTTPMethod.get
    var queryItems: [URLQueryItem] = []
    var body: Data?
    var requiresAuthentication = false
    var allowsOptionalAuthentication = false
    var idempotencyKey: UUID?
}

enum BackendError: LocalizedError, Equatable {
    case invalidRequest
    case networkUnavailable
    case authenticationRequired
    case invalidSession
    case server(status: Int, code: String?, message: String, retryAfterSeconds: Int?)
    case invalidResponse
    case unsupportedWorkoutType

    var errorDescription: String? {
        switch self {
        case .invalidRequest: return "请求配置无效。"
        case .networkUnavailable: return "无法连接本地后端，请确认服务已启动且地址配置正确。"
        case .authenticationRequired: return "登录已失效，请重新登录。"
        case .invalidSession: return "安全会话无效，请重新登录。"
        case let .server(_, code, message, _):
            if code == "verification_provider_unavailable"
                || code == "verification_delivery_unavailable" {
                return "服务端尚未配置短信或邮件验证服务，暂时无法注册。"
            }
            if code == "invalid_credentials" { return "账号或密码错误。" }
            if code == "profile_version_conflict" { return "资料已在其他设备更新，请刷新后重试。" }
            return message.isEmpty ? "服务端请求失败。" : message
        case .invalidResponse: return "服务端返回的数据格式不符合接口契约。"
        case .unsupportedWorkoutType: return "当前服务端不支持同步该运动类型，记录已保存在本机。"
        }
    }
}

private struct ProblemDetailsDTO: Decodable {
    let title: String?
    let detail: String?
    let code: String?
}

private struct TokenPairDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
}

actor MoveFitAPIClient {
    private let baseURL: URL
    private let urlSession: URLSession
    private let sessionStore: BackendSessionStore
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var refreshTask: Task<Void, Error>?

    init(
        baseURL: URL,
        urlSession: URLSession = .shared,
        sessionStore: BackendSessionStore
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.sessionStore = sessionStore
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func encode<Body: Encodable>(_ body: Body) throws -> Data {
        try encoder.encode(body)
    }

    func send<Response: Decodable>(_ request: BackendRequest, as type: Response.Type) async throws -> Response {
        let data = try await perform(request, canRefresh: true)
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw BackendError.invalidResponse
        }
    }

    func sendWithoutResponse(_ request: BackendRequest) async throws {
        _ = try await perform(request, canRefresh: true)
    }

    func storeSession(
        tokenResponseData: Data,
        kind: AccountIdentifierKind,
        identifier: String,
        sessionID: UUID
    ) async throws {
        let tokenPair: TokenPairDTO
        do {
            tokenPair = try decoder.decode(TokenPairDTO.self, from: tokenResponseData)
        } catch {
            throw BackendError.invalidResponse
        }
        try await sessionStore.save(
            StoredBackendSession(
                accessToken: tokenPair.accessToken,
                refreshToken: tokenPair.refreshToken,
                sessionID: sessionID,
                identifierKind: kind,
                identifier: identifier
            )
        )
    }

    func sendForSession(_ request: BackendRequest) async throws -> Data {
        try await perform(request, canRefresh: false)
    }

    func storeSocialSession(
        tokenResponseData: Data,
        provider: SocialProvider,
        sessionID: UUID
    ) async throws {
        let tokenPair: TokenPairDTO
        do {
            tokenPair = try decoder.decode(TokenPairDTO.self, from: tokenResponseData)
        } catch {
            throw BackendError.invalidResponse
        }
        guard tokenPair.tokenType.caseInsensitiveCompare("Bearer") == .orderedSame,
              !tokenPair.accessToken.isEmpty,
              !tokenPair.refreshToken.isEmpty else {
            throw BackendError.invalidResponse
        }
        try await sessionStore.save(
            StoredBackendSession(
                accessToken: tokenPair.accessToken,
                refreshToken: tokenPair.refreshToken,
                sessionID: sessionID,
                identifierKind: nil,
                identifier: provider.authenticationMethod.rawValue,
                socialProvider: provider
            )
        )
    }

    func storedSession() async throws -> StoredBackendSession? {
        try await sessionStore.session()
    }

    func clearSession() async {
        try? await sessionStore.clear()
    }

    private func perform(_ request: BackendRequest, canRefresh: Bool) async throws -> Data {
        let urlRequest = try await makeURLRequest(request)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw BackendError.networkUnavailable
        }
        guard let httpResponse = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        if (200..<300).contains(httpResponse.statusCode) { return data }
        if httpResponse.statusCode == 401, request.requiresAuthentication, canRefresh {
            do {
                try await refreshTokens()
                return try await perform(request, canRefresh: false)
            } catch {
                await clearSession()
                throw BackendError.authenticationRequired
            }
        }
        throw makeServerError(response: httpResponse, data: data)
    }

    private func makeURLRequest(_ request: BackendRequest) async throws -> URLRequest {
        let url = baseURL.appendingPathComponent(request.path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidRequest
        }
        components.queryItems = request.queryItems.isEmpty ? nil : request.queryItems
        guard let finalURL = components.url else { throw BackendError.invalidRequest }
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = 20
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let key = request.idempotencyKey {
            urlRequest.setValue(key.uuidString, forHTTPHeaderField: "Idempotency-Key")
        }
        if request.requiresAuthentication || request.allowsOptionalAuthentication {
            let session = try await sessionStore.session()
            if request.requiresAuthentication, session == nil {
                throw BackendError.authenticationRequired
            }
            if let session {
                urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            }
        }
        return urlRequest
    }

    private func refreshTokens() async throws {
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task { try await self.executeTokenRefresh() }
        refreshTask = task
        do {
            try await task.value
            refreshTask = nil
        } catch {
            refreshTask = nil
            throw error
        }
    }

    private func executeTokenRefresh() async throws {
        guard let session = try await sessionStore.session() else {
            throw BackendError.authenticationRequired
        }
        struct RefreshBody: Encodable { let refreshToken: String }
        let body = try encoder.encode(RefreshBody(refreshToken: session.refreshToken))
        let request = BackendRequest(path: "api/v1/auth/token/refresh", method: .post, body: body)
        let data = try await perform(request, canRefresh: false)
        let tokenPair: TokenPairDTO
        do {
            tokenPair = try decoder.decode(TokenPairDTO.self, from: data)
        } catch {
            throw BackendError.invalidResponse
        }
        try await sessionStore.update(
            accessToken: tokenPair.accessToken,
            refreshToken: tokenPair.refreshToken
        )
    }

    private func makeServerError(response: HTTPURLResponse, data: Data) -> BackendError {
        let problem = try? decoder.decode(ProblemDetailsDTO.self, from: data)
        return .server(
            status: response.statusCode,
            code: problem?.code,
            message: problem?.detail
                ?? problem?.title
                ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
            retryAfterSeconds: Self.retryAfterSeconds(
                from: response.value(forHTTPHeaderField: "Retry-After")
            )
        )
    }

    private static func retryAfterSeconds(from rawValue: String?) -> Int? {
        guard let rawValue,
              let seconds = Int(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1 ... 86_400).contains(seconds) else {
            return nil
        }
        return seconds
    }
}

enum BackendDateParser {
    static func date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
