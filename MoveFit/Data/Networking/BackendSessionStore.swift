import Foundation

struct StoredBackendSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    let sessionID: UUID
    let identifierKind: AccountIdentifierKind?
    let identifier: String
    let socialProvider: SocialProvider?

    init(
        accessToken: String,
        refreshToken: String,
        sessionID: UUID,
        identifierKind: AccountIdentifierKind?,
        identifier: String,
        socialProvider: SocialProvider? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.sessionID = sessionID
        self.identifierKind = identifierKind
        self.identifier = identifier
        self.socialProvider = socialProvider
    }
}

actor BackendSessionStore {
    private let credentials: CredentialStoring
    private let account = "movefit-backend-session"

    init(credentials: CredentialStoring = KeychainStore()) {
        self.credentials = credentials
    }

    func session() throws -> StoredBackendSession? {
        guard let value = try credentials.token(account: account),
              let data = value.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(StoredBackendSession.self, from: data)
        } catch {
            try? credentials.delete(account: account)
            throw BackendError.invalidSession
        }
    }

    func save(_ session: StoredBackendSession) throws {
        let data = try JSONEncoder().encode(session)
        guard let value = String(data: data, encoding: .utf8) else {
            throw BackendError.invalidSession
        }
        try credentials.save(token: value, account: account)
    }

    func update(accessToken: String, refreshToken: String) throws {
        guard var current = try session() else { throw BackendError.authenticationRequired }
        current.accessToken = accessToken
        current.refreshToken = refreshToken
        try save(current)
    }

    func clear() throws {
        try credentials.delete(account: account)
    }
}
