import XCTest
@testable import MoveFit

@MainActor
final class GoogleOAuthAdapterTests: XCTestCase {
    func testPKCEChallengeUsesS256Base64URL() throws {
        let verifier = String(repeating: "a", count: 43)
        let challenge = GooglePKCE.challenge(for: verifier)

        XCTAssertEqual(challenge.count, 43)
        XCTAssertTrue(challenge.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        XCTAssertNotEqual(challenge, verifier)
    }

    func testValidCallbackPreservesOriginalVerifierAndServerState() async throws {
        let handoff = GoogleHandoffFake()
        let browser = GoogleBrowserFake()
        let redirect = try XCTUnwrap(URL(string: "com.movefit.mobile:/oauth2redirect"))
        browser.callback = try XCTUnwrap(URL(string: "com.movefit.mobile:/oauth2redirect?code=fictional-code&state=fictional-state"))
        let adapter = GoogleOAuthAdapter(
            handoff: handoff,
            browser: browser,
            redirectURI: redirect,
            pkce: GooglePKCEFake()
        )

        let completion = try await adapter.authorize(deviceID: "fictional-device")

        XCTAssertEqual(handoff.codeChallenge, GooglePKCE.challenge(for: String(repeating: "a", count: 43)))
        XCTAssertEqual(browser.callbackScheme, "com.movefit.mobile")
        XCTAssertEqual(completion.authorizationCode, "fictional-code")
        XCTAssertEqual(completion.state, "fictional-state")
        XCTAssertEqual(completion.codeVerifier, String(repeating: "a", count: 43))
        XCTAssertEqual(completion.redirectURI, redirect)
    }

    func testWrongStateOrRedirectNeverProducesCompletion() async throws {
        let redirect = try XCTUnwrap(URL(string: "com.movefit.mobile:/oauth2redirect"))
        for value in [
            "com.movefit.mobile:/oauth2redirect?code=fictional-code&state=wrong",
            "com.movefit.mobile:/other?code=fictional-code&state=fictional-state",
            "com.movefit.mobile:/oauth2redirect?state=fictional-state",
            "com.movefit.mobile:/oauth2redirect?code=fictional-code&state=fictional-state&state",
            "com.movefit.mobile:/oauth2redirect?code=fictional-code&state=fictional-state&code",
            "com.movefit.mobile:/oauth2redirect?code=fictional-code&state=fictional-state&error=access_denied"
        ] {
            let browser = GoogleBrowserFake()
            browser.callback = try XCTUnwrap(URL(string: value))
            let adapter = GoogleOAuthAdapter(
                handoff: GoogleHandoffFake(),
                browser: browser,
                redirectURI: redirect,
                pkce: GooglePKCEFake()
            )
            do {
                _ = try await adapter.authorize(deviceID: "fictional-device")
                XCTFail("Invalid callback must not produce a completion")
            } catch let error as GoogleOAuthError {
                XCTAssertTrue([.invalidCallback, .stateMismatch].contains(error))
            }
        }
    }

    func testBrowserCancellationIsTypedAndNeverCompletesAuthentication() async throws {
        let browser = GoogleBrowserFake()
        browser.error = .cancelled
        let adapter = GoogleOAuthAdapter(
            handoff: GoogleHandoffFake(),
            browser: browser,
            redirectURI: try XCTUnwrap(URL(string: "com.movefit.mobile:/oauth2redirect")),
            pkce: GooglePKCEFake()
        )
        do {
            _ = try await adapter.authorize(deviceID: "fictional-device")
            XCTFail("Expected cancellation")
        } catch let error as GoogleOAuthError {
            XCTAssertEqual(error, .cancelled)
        }
    }

    func testInvalidPKCEVerifierStopsBeforeProviderHandoff() async throws {
        let handoff = GoogleHandoffFake()
        let adapter = GoogleOAuthAdapter(
            handoff: handoff,
            browser: GoogleBrowserFake(),
            redirectURI: try XCTUnwrap(URL(string: "com.movefit.mobile:/oauth2redirect")),
            pkce: InvalidGooglePKCEFake()
        )

        do {
            _ = try await adapter.authorize(deviceID: "fictional-device")
            XCTFail("Invalid PKCE verifier must not start OAuth")
        } catch let error as GoogleOAuthError {
            XCTAssertEqual(error, .unavailable)
            XCTAssertNil(handoff.codeChallenge)
        }
    }
}

private final class GoogleHandoffFake: GoogleAuthorizationHandoffProviding {
    private(set) var codeChallenge: String?

    func beginGoogleAuthorization(
        redirectURI: URL,
        codeChallenge: String,
        deviceID: String
    ) async throws -> GoogleAuthorizationHandoff {
        self.codeChallenge = codeChallenge
        guard let authorizationURL = URL(string: "https://accounts.google.test/auth") else {
            throw GoogleOAuthError.invalidCallback
        }
        return GoogleAuthorizationHandoff(
            authorizationURL: authorizationURL,
            state: "fictional-state",
            expiresAt: Date().addingTimeInterval(300)
        )
    }
}

@MainActor
private final class GoogleBrowserFake: GoogleBrowserAuthenticating {
    var callback: URL?
    var error: GoogleOAuthError?
    private(set) var callbackScheme: String?

    func authenticate(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        self.callbackScheme = callbackScheme
        if let error { throw error }
        guard let callback else { throw GoogleOAuthError.invalidCallback }
        return callback
    }
}

private struct GooglePKCEFake: GooglePKCEProviding {
    func makeVerifier() throws -> String { String(repeating: "a", count: 43) }
    func challenge(for verifier: String) -> String { GooglePKCE.challenge(for: verifier) }
}

private struct InvalidGooglePKCEFake: GooglePKCEProviding {
    func makeVerifier() throws -> String { "too-short" }
    func challenge(for verifier: String) -> String { GooglePKCE.challenge(for: verifier) }
}
