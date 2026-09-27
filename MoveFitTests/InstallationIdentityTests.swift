import XCTest
@testable import MoveFit

final class InstallationIdentityTests: XCTestCase {
    func testInstallationIdentityGeneratesOnceAndReusesStoredUUID() throws {
        let store = InstallationCredentialStoreFake()
        let generated = UUID(uuidString: "00000000-0000-0000-0000-000000000701")!
        let uuidProvider = InstallationUUIDProviderFake(values: [generated])
        let identity = KeychainInstallationIdentity(
            credentials: store,
            uuidProvider: uuidProvider
        )

        let first = try identity.installationID()
        let second = try identity.installationID()

        XCTAssertEqual(first, generated.uuidString)
        XCTAssertEqual(second, generated.uuidString)
        XCTAssertEqual(uuidProvider.callCount, 1)
        XCTAssertEqual(store.savedValues.count, 1)
    }

    func testInstallationIdentityReplacesCorruptStoredValue() throws {
        let store = InstallationCredentialStoreFake()
        store.value = "not-a-valid-uuid"
        let replacement = UUID(uuidString: "00000000-0000-0000-0000-000000000702")!
        let uuidProvider = InstallationUUIDProviderFake(values: [replacement])
        let identity = KeychainInstallationIdentity(
            credentials: store,
            uuidProvider: uuidProvider
        )

        let value = try identity.installationID()

        XCTAssertEqual(value, replacement.uuidString)
        XCTAssertEqual(store.deleteCount, 1)
        XCTAssertEqual(store.value, replacement.uuidString)
    }
}

private final class InstallationCredentialStoreFake: CredentialStoring {
    var value: String?
    var savedValues: [String] = []
    var deleteCount = 0

    func save(token: String, account: String) throws {
        XCTAssertEqual(account, "movefit-installation-id")
        value = token
        savedValues.append(token)
    }

    func token(account: String) throws -> String? {
        XCTAssertEqual(account, "movefit-installation-id")
        return value
    }

    func delete(account: String) throws {
        XCTAssertEqual(account, "movefit-installation-id")
        deleteCount += 1
        value = nil
    }
}

private final class InstallationUUIDProviderFake: UUIDProviding {
    private var values: [UUID]
    private(set) var callCount = 0

    init(values: [UUID]) {
        self.values = values
    }

    func make() -> UUID {
        callCount += 1
        return values.removeFirst()
    }
}
