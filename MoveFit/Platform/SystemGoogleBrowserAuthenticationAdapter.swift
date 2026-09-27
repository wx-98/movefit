import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class SystemGoogleBrowserAuthenticationAdapter: NSObject, GoogleBrowserAuthenticating {
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, Error>?
    private var anchor: ASPresentationAnchor?

    func authenticate(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        guard session == nil,
              authorizationURL.scheme == "https",
              !callbackScheme.isEmpty,
              let anchor = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) else {
            throw GoogleOAuthError.unavailable
        }
        self.anchor = anchor
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let session = ASWebAuthenticationSession(
                    url: authorizationURL,
                    callbackURLScheme: callbackScheme
                ) { [weak self] callback, error in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let callback {
                            self.finish(.success(callback))
                        } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                            self.finish(.failure(GoogleOAuthError.cancelled))
                        } else {
                            self.finish(.failure(GoogleOAuthError.unavailable))
                        }
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                self.session = session
                if !session.start() {
                    finish(.failure(GoogleOAuthError.unavailable))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.session?.cancel()
                self?.finish(.failure(GoogleOAuthError.cancelled))
            }
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        session = nil
        anchor = nil
        continuation.resume(with: result)
    }
}

extension SystemGoogleBrowserAuthenticationAdapter: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor ?? UIWindow()
    }
}
