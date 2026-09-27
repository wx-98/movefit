import Foundation
import XCTest

final class RegistrationSecurityRegressionTests: XCTestCase {
    func testRegistrationFlowSourcesDoNotUseLogsOrPersistenceForSensitiveState() throws {
        let root = projectRoot()
        let relativePaths = [
            "MoveFit/Domain/RegistrationVerification.swift",
            "MoveFit/Domain/RegistrationVerificationUseCases.swift",
            "MoveFit/Features/Profile/RegistrationViewModel.swift"
        ]
        let forbiddenAPIs = [
            "print(",
            "NSLog(",
            "os_log(",
            "Logger(",
            "UserDefaults",
            "@AppStorage",
            "CoreData",
            "PersistenceController",
            "KeychainStore"
        ]

        for relativePath in relativePaths {
            let source = try String(
                contentsOf: root.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            for forbiddenAPI in forbiddenAPIs {
                XCTAssertFalse(
                    source.contains(forbiddenAPI),
                    "Sensitive registration state must not reach \(forbiddenAPI) in \(relativePath)"
                )
            }
        }
    }

    func testApplicationBundleSourcesContainNoTencentCloudCredentialNames() throws {
        let sourceRoot = projectRoot().appendingPathComponent("MoveFit")
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: nil
            )
        )
        let forbiddenCredentialNames = [
            "TENCENT_SECRET_ID",
            "TENCENT_SECRET_KEY",
            "TENCENT_SMS_SDK_APP_ID",
            "TENCENT_SMS_SIGN_NAME",
            "TENCENT_SMS_TEMPLATE_ID"
        ]

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for credentialName in forbiddenCredentialNames {
                XCTAssertFalse(
                    source.contains(credentialName),
                    "Tencent Cloud credential \(credentialName) must remain server-side"
                )
            }
        }
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
