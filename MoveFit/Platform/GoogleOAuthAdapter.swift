import Foundation

enum GoogleOAuthError: Error, Equatable {
    case notConfigured
    case unavailable
    case cancelled
    case invalidCallback
    case stateMismatch
    case expiredHandoff
}

@MainActor
protocol GoogleBrowserAuthenticating {
    func authenticate(authorizationURL: URL, callbackScheme: String) async throws -> URL
}

@MainActor
final class GoogleOAuthAdapter {
    private let handoff: GoogleAuthorizationHandoffProviding
    private let browser: GoogleBrowserAuthenticating
    private let redirectURI: URL?
    private let pkce: GooglePKCEProviding
    private let dateProvider: DateProviding

    init(
        handoff: GoogleAuthorizationHandoffProviding,
        browser: GoogleBrowserAuthenticating,
        redirectURI: URL?,
        pkce: GooglePKCEProviding = GooglePKCE(),
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        self.handoff = handoff
        self.browser = browser
        self.redirectURI = redirectURI
        self.pkce = pkce
        self.dateProvider = dateProvider
    }

    func authorize(deviceID: String) async throws -> GoogleAuthorizationCompletion {
        guard let redirectURI,
              let scheme = redirectURI.scheme,
              !scheme.isEmpty,
              scheme != "http", scheme != "https",
              !redirectURI.path.isEmpty,
              !deviceID.isEmpty, deviceID.count <= 191 else {
            throw GoogleOAuthError.notConfigured
        }
        let verifier = try pkce.makeVerifier()
        guard (43...128).contains(verifier.count),
              verifier.utf8.allSatisfy({ byte in
                  (65...90).contains(byte) || (97...122).contains(byte)
                      || (48...57).contains(byte) || [45, 46, 95, 126].contains(byte)
              }) else {
            throw GoogleOAuthError.unavailable
        }
        let response = try await handoff.beginGoogleAuthorization(
            redirectURI: redirectURI,
            codeChallenge: pkce.challenge(for: verifier),
            deviceID: deviceID
        )
        guard response.expiresAt > dateProvider.now else { throw GoogleOAuthError.expiredHandoff }
        guard response.authorizationURL.scheme == "https", !response.state.isEmpty else {
            throw GoogleOAuthError.invalidCallback
        }
        let callback = try await browser.authenticate(
            authorizationURL: response.authorizationURL,
            callbackScheme: scheme
        )
        guard response.expiresAt > dateProvider.now else { throw GoogleOAuthError.expiredHandoff }
        let code = try Self.authorizationCode(
            from: callback,
            expectedRedirect: redirectURI,
            expectedState: response.state
        )
        return GoogleAuthorizationCompletion(
            authorizationCode: code,
            state: response.state,
            codeVerifier: verifier,
            redirectURI: redirectURI,
            deviceID: deviceID
        )
    }

    private static func authorizationCode(
        from callback: URL,
        expectedRedirect: URL,
        expectedState: String
    ) throws -> String {
        guard let actual = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              let expected = URLComponents(url: expectedRedirect, resolvingAgainstBaseURL: false),
              actual.scheme == expected.scheme,
              actual.host == expected.host,
              actual.port == expected.port,
              actual.path == expected.path,
              actual.fragment == nil,
              let parameters = actual.queryItems else {
            throw GoogleOAuthError.invalidCallback
        }
        let states = parameters.filter { $0.name == "state" }
        let codes = parameters.filter { $0.name == "code" }
        guard parameters.allSatisfy({ $0.name == "state" || $0.name == "code" }),
              states.count == 1, codes.count == 1,
              let state = states[0].value, !state.isEmpty,
              let code = codes[0].value, !code.isEmpty else {
            throw GoogleOAuthError.invalidCallback
        }
        guard state == expectedState else { throw GoogleOAuthError.stateMismatch }
        return code
    }
}
