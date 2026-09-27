import XCTest
@testable import MoveFit

final class SocialAuthorizationAdapterTests: XCTestCase {
    @MainActor
    func testWechatWithoutSDKReturnsUnavailableInsteadOfAuthorizationCode() async {
        let adapter = UnavailableWechatAuthorizationAdapter()

        do {
            _ = try await adapter.authorization(deviceID: "fictional-installation")
            XCTFail("An unconfigured adapter must not issue an authorization code")
        } catch let error as SocialAuthorizationError {
            XCTAssertEqual(error, .providerNotConfigured)
        } catch {
            XCTFail("Expected a typed unavailable state")
        }
    }

    func testAppleNonceUsesCryptographicRandomURLSafeValue() throws {
        let first = try AppleAuthorizationNonce.generate()
        let second = try AppleAuthorizationNonce.generate()

        XCTAssertNotEqual(first, second)
        XCTAssertGreaterThanOrEqual(first.count, 32)
        XCTAssertTrue(first.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }
}
