import Foundation

final class KeychainInstallationIdentity: InstallationIdentifying {
    private let credentials: CredentialStoring
    private let uuidProvider: UUIDProviding
    private let account = "movefit-installation-id"
    private let lock = NSLock()

    init(
        credentials: CredentialStoring = KeychainStore(service: "com.movefit.app.installation"),
        uuidProvider: UUIDProviding = SystemUUIDProvider()
    ) {
        self.credentials = credentials
        self.uuidProvider = uuidProvider
    }

    func installationID() throws -> String {
        lock.lock()
        defer { lock.unlock() }

        if let storedValue = try credentials.token(account: account) {
            if let storedUUID = UUID(uuidString: storedValue) {
                return storedUUID.uuidString
            }
            try credentials.delete(account: account)
        }

        let generatedValue = uuidProvider.make().uuidString
        try credentials.save(token: generatedValue, account: account)
        return generatedValue
    }
}
