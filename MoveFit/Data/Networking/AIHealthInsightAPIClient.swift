import Foundation

struct AIInsightAccessDTO: Decodable {
    let access: String
    let capabilityVersion: String?
}

struct AIInsightDTO: Decodable {
    let id: UUID
    let title: String
    let message: String
    let modelVersion: String
    let generatedAt: String
    let safetyNotice: String
}

struct AIInsightAnalyzeResponseDTO: Decodable {
    let insights: [AIInsightDTO]
}

actor AIHealthInsightAPIClient {
    private let baseURL: URL
    private let urlSession: URLSession
    private let sessionStore: BackendSessionStore
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL,
        sessionStore: BackendSessionStore,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.sessionStore = sessionStore
        self.urlSession = urlSession
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func access(metric: String) async throws -> AIInsightAccessDTO {
        try await send(path: "api/v1/health-insights/access", method: .get, queryItems: [
            URLQueryItem(name: "metric", value: metric)
        ])
    }

    func analyze<Body: Encodable>(_ body: Body, idempotencyKey: UUID) async throws -> AIInsightAnalyzeResponseDTO {
        let data = try encoder.encode(body)
        return try await send(
            path: "api/v1/health-insights/analyze",
            method: .post,
            body: data,
            requiresAuthentication: true,
            idempotencyKey: idempotencyKey
        )
    }

    private func send<Response: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        requiresAuthentication: Bool = false,
        idempotencyKey: UUID? = nil
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidRequest
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let finalURL = components.url else { throw BackendError.invalidRequest }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let idempotencyKey { request.setValue(idempotencyKey.uuidString, forHTTPHeaderField: "Idempotency-Key") }
        if requiresAuthentication {
            guard let session = try await sessionStore.session() else { throw BackendError.authenticationRequired }
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        } else if let session = try await sessionStore.session() {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                throw BackendError.server(
                    status: httpResponse.statusCode,
                    code: nil,
                    message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                    retryAfterSeconds: nil
                )
            }
            return try decoder.decode(Response.self, from: data)
        } catch let error as BackendError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch is DecodingError {
            throw BackendError.invalidResponse
        } catch {
            throw BackendError.networkUnavailable
        }
    }
}
