import Foundation

enum SocialProvider: String, CaseIterable, Codable {
    case apple
    case wechat
    case google
}

extension SocialProvider {
    var authenticationMethod: AuthenticationMethod {
        switch self {
        case .apple: return .apple
        case .wechat: return .wechat
        case .google: return .google
        }
    }
}

struct SocialIdentity: Equatable {
    let provider: SocialProvider
    let maskedHint: String?
    let linkedAt: Date
}

struct SocialAuthorization {
    let authorizationCode: String
    let nonce: String?
    let deviceID: String
}

struct GoogleAuthorizationHandoff {
    let authorizationURL: URL
    let state: String
    let expiresAt: Date
}

struct GoogleAuthorizationCompletion {
    let authorizationCode: String
    let state: String
    let codeVerifier: String
    let redirectURI: URL
    let deviceID: String
}

enum SocialAuthorizationError: Error, Equatable {
    case cancelled
    case providerNotConfigured
    case authorizationFailed
    case unavailable
}

@MainActor
protocol SocialAuthorizationCodeProviding {
    func authorization(deviceID: String) async throws -> SocialAuthorization
}
