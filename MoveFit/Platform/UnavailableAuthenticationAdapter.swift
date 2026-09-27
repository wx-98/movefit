import Foundation

actor UnavailableAuthenticationAdapter: AuthenticationProviding {
    func restoreSession() async throws -> AccountSession? { nil }

    func signIn(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String
    ) async throws -> AccountSession {
        throw BackendError.networkUnavailable
    }

    func register(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String,
        verificationProof: String
    ) async throws {
        throw BackendError.networkUnavailable
    }

    func signOut(allSessions: Bool) async {}
}
