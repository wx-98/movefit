import Foundation

struct AppEnvironment: Equatable {
    let backendBaseURL: URL
    let exerciseBaseURL: URL
    let aiBaseURL: URL
    let googleRedirectURI: URL?

    init(backendBaseURL: URL, exerciseBaseURL: URL, aiBaseURL: URL, googleRedirectURI: URL? = nil) {
        self.backendBaseURL = backendBaseURL
        self.exerciseBaseURL = exerciseBaseURL
        self.aiBaseURL = aiBaseURL
        self.googleRedirectURI = googleRedirectURI
    }

    init(bundle: Bundle = .main) throws {
        backendBaseURL = try Self.url(for: "MoveFitBackendBaseURL", bundle: bundle)
        exerciseBaseURL = try Self.url(for: "MoveFitExerciseBaseURL", bundle: bundle)
        aiBaseURL = try Self.url(for: "MoveFitAIBaseURL", bundle: bundle)
        googleRedirectURI = Self.googleRedirectURI(bundle: bundle)
    }

    static var current: AppEnvironment {
        do {
            return try AppEnvironment()
        } catch {
            assertionFailure("后端环境配置无效：\(error.localizedDescription)")
            return AppEnvironment(
                backendBaseURL: Self.localURL(port: 8000),
                exerciseBaseURL: Self.localURL(port: 8001),
                aiBaseURL: Self.localURL(port: 8002),
                googleRedirectURI: nil
            )
        }
    }

    static func url(for key: String, infoDictionary: [String: Any]) throws -> URL {
        guard let value = infoDictionary[key] as? String,
              !value.isEmpty,
              !value.contains("$("),
              let url = URL(string: value),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw AppEnvironmentError.invalidValue(key)
        }
        return url
    }

    private static func url(for key: String, bundle: Bundle) throws -> URL {
        try url(for: key, infoDictionary: bundle.infoDictionary ?? [:])
    }

    private static func localURL(port: Int) -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = port
        return components.url ?? URL(fileURLWithPath: "/")
    }

    static func googleRedirectURI(infoDictionary: [String: Any]) -> URL? {
        guard let value = infoDictionary["MoveFitGoogleRedirectURI"] as? String,
              !value.contains("$("),
              let url = URL(string: value),
              let scheme = url.scheme,
              !["http", "https"].contains(scheme),
              !url.path.isEmpty,
              let types = infoDictionary["CFBundleURLTypes"] as? [[String: Any]],
              types.contains(where: { type in
                  (type["CFBundleURLSchemes"] as? [String])?.contains(scheme) == true
              }) else {
            return nil
        }
        return url
    }

    private static func googleRedirectURI(bundle: Bundle) -> URL? {
        googleRedirectURI(infoDictionary: bundle.infoDictionary ?? [:])
    }
}

enum AppEnvironmentError: LocalizedError, Equatable {
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case let .invalidValue(key): return "配置项 \(key) 缺失或不是有效的 HTTP(S) 地址。"
        }
    }
}
