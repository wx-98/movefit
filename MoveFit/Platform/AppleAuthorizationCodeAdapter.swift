import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class AppleAuthorizationCodeAdapter: NSObject, SocialAuthorizationCodeProviding {
    private var continuation: CheckedContinuation<SocialAuthorization, Error>?
    private var pendingNonce: String?
    private var pendingDeviceID: String?
    private var presentationAnchor: ASPresentationAnchor?
    private var controller: ASAuthorizationController?

    func authorization(deviceID: String) async throws -> SocialAuthorization {
        guard !deviceID.isEmpty, deviceID.count <= 191,
              continuation == nil,
              let anchor = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) else {
            throw SocialAuthorizationError.unavailable
        }
        let nonce = try AppleAuthorizationNonce.generate()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.nonce = nonce
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        presentationAnchor = anchor
        pendingNonce = nonce
        pendingDeviceID = deviceID

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                controller.performRequests()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(.failure(SocialAuthorizationError.cancelled))
            }
        }
    }

    private func finish(_ result: Result<SocialAuthorization, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        pendingNonce = nil
        pendingDeviceID = nil
        presentationAnchor = nil
        controller = nil
        continuation.resume(with: result)
    }
}

extension AppleAuthorizationCodeAdapter: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.authorizationCode,
              let code = String(data: data, encoding: .utf8),
              !code.isEmpty,
              let nonce = pendingNonce,
              let deviceID = pendingDeviceID else {
            finish(.failure(SocialAuthorizationError.authorizationFailed))
            return
        }
        finish(.success(SocialAuthorization(
            authorizationCode: code,
            nonce: nonce,
            deviceID: deviceID
        )))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let authorizationError = error as? ASAuthorizationError
        let mapped: SocialAuthorizationError = authorizationError?.code == .canceled
            ? .cancelled : .authorizationFailed
        finish(.failure(mapped))
    }
}

extension AppleAuthorizationCodeAdapter: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor ?? UIWindow()
    }
}
