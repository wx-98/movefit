import Foundation

struct UnavailableWechatAuthorizationAdapter: SocialAuthorizationCodeProviding {
    func authorization(deviceID: String) async throws -> SocialAuthorization {
        throw SocialAuthorizationError.providerNotConfigured
    }
}
