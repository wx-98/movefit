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
#if DEBUG
        let requiresProductionHTTPS = false
#else
        let requiresProductionHTTPS = true
#endif
        backendBaseURL = try Self.url(
            for: "MoveFitBackendBaseURL", bundle: bundle, requiresProductionHTTPS: requiresProductionHTTPS
        )
        exerciseBaseURL = try Self.url(
            for: "MoveFitExerciseBaseURL", bundle: bundle, requiresProductionHTTPS: requiresProductionHTTPS
        )
        aiBaseURL = try Self.url(
            for: "MoveFitAIBaseURL", bundle: bundle, requiresProductionHTTPS: requiresProductionHTTPS
        )
        googleRedirectURI = Self.googleRedirectURI(bundle: bundle)
    }

    static var current: AppEnvironment {
        do {
            return try AppEnvironment()
        } catch {
#if DEBUG
            assertionFailure("Invalid backend environment configuration: \(error.localizedDescription)")
            return AppEnvironment(
                backendBaseURL: Self.localURL(port: 8000),
                exerciseBaseURL: Self.localURL(port: 8001),
                aiBaseURL: Self.localURL(port: 8002),
                googleRedirectURI: nil
            )
#else
            // Release must fail closed rather than silently connecting to a developer loopback service.
            preconditionFailure("Invalid backend environment configuration: \(error.localizedDescription)")
#endif
        }
    }

    static func url(
        for key: String,
        infoDictionary: [String: Any],
        requiresProductionHTTPS: Bool = false
    ) throws -> URL {
        guard let value = infoDictionary[key] as? String,
              !value.isEmpty,
              !value.contains("$("),
              let url = URL(string: value),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw AppEnvironmentError.invalidValue(key)
        }
        if requiresProductionHTTPS {
            guard scheme == "https", url.user == nil, url.password == nil,
                  let host = url.host, Self.isProductionDomain(host) else {
                throw AppEnvironmentError.invalidValue(key)
            }
        }
        return url
    }

    private static func url(
        for key: String,
        bundle: Bundle,
        requiresProductionHTTPS: Bool
    ) throws -> URL {
        try url(
            for: key,
            infoDictionary: bundle.infoDictionary ?? [:],
            requiresProductionHTTPS: requiresProductionHTTPS
        )
    }

    private static func isProductionDomain(_ value: String) -> Bool {
        let host = value.lowercased()
        let labels = host.split(separator: ".")
        guard labels.count >= 2,
              !host.contains(":"),
              !host.contains("placeholder"),
              !host.contains("replace-before-release"),
              !["invalid", "test", "example", "localhost", "local"].contains(String(labels.last ?? "")),
              !["example.com", "example.org", "example.net"].contains(host),
              !labels.allSatisfy({ label in label.allSatisfy(\.isNumber) }) else {
            return false
        }
        return true
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
        case let .invalidValue(key): return "Invalid value for \(key): expected a valid HTTP(S) address."
        }
    }
}
