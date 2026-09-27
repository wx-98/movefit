import Foundation

enum SocialIdentityDTO {
    struct Item: Decodable {
        let provider: String
        let maskedHint: String?
        let linkedAt: String

        func domain() throws -> SocialIdentity {
            guard let provider = SocialProvider(rawValue: provider),
                  let linkedAt = BackendDateParser.date(from: linkedAt) else {
                throw BackendError.invalidResponse
            }
            return SocialIdentity(provider: provider, maskedHint: maskedHint, linkedAt: linkedAt)
        }
    }

    struct List: Decodable {
        let items: [Item]
    }

    struct AuthorizationRequest: Encodable {
        let authorizationCode: String
        let nonce: String?
        let deviceID: String
    }

    struct GoogleHandoffRequest: Encodable {
        let redirectURI: String
        let codeChallenge: String
        let deviceID: String
    }

    struct GoogleHandoff: Decodable {
        let authorizationUrl: String
        let state: String
        let expiresAt: String

        func domain() throws -> GoogleAuthorizationHandoff {
            guard let url = URL(string: authorizationUrl), url.scheme == "https",
                  !state.isEmpty,
                  let expiresAt = BackendDateParser.date(from: expiresAt) else {
                throw BackendError.invalidResponse
            }
            return GoogleAuthorizationHandoff(authorizationURL: url, state: state, expiresAt: expiresAt)
        }
    }

    struct GoogleCompletionRequest: Encodable {
        let authorizationCode: String
        let state: String
        let codeVerifier: String
        let redirectURI: String
        let deviceID: String
    }
}
