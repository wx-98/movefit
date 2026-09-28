import XCTest
@testable import MoveFit

final class AppEnvironmentTests: XCTestCase {
    private var createdFixtureRoots: [URL] = []

    override func tearDown() {
        for root in createdFixtureRoots {
            try? FileManager.default.removeItem(at: root)
        }
        createdFixtureRoots = []
        super.tearDown()
    }

    func testURLAcceptsHTTPAndHTTPSValues() throws {
        XCTAssertEqual(
            try AppEnvironment.url(for: "MoveFitBackendBaseURL", infoDictionary: [
                "MoveFitBackendBaseURL": "https://api.example.com"
            ]),
            URL(string: "https://api.example.com")
        )
        XCTAssertEqual(
            try AppEnvironment.url(for: "MoveFitExerciseBaseURL", infoDictionary: [
                "MoveFitExerciseBaseURL": "http://192.168.1.10:8001"
            ]),
            URL(string: "http://192.168.1.10:8001")
        )
    }

    func testURLRejectsMissingEmptyPlaceholderAndInvalidValues() {
        let cases: [[String: Any]] = [
            [:],
            ["MoveFitBackendBaseURL": ""],
            ["MoveFitBackendBaseURL": "$(MOVEFIT_BACKEND_BASE_URL)"],
            ["MoveFitBackendBaseURL": "ftp://api.example.com"],
            ["MoveFitBackendBaseURL": "https:/api.example.com"],
            ["MoveFitBackendBaseURL": "not a url"]
        ]
        for info in cases {
            XCTAssertThrowsError(try AppEnvironment.url(for: "MoveFitBackendBaseURL", infoDictionary: info)) { error in
                XCTAssertEqual(
                    error as? AppEnvironmentError,
                    .invalidValue("MoveFitBackendBaseURL"),
                    "应拒绝配置：\(info)"
                )
            }
        }
    }

    func testProductionURLRequiresPublicHTTPSDomain() throws {
        XCTAssertEqual(
            try AppEnvironment.url(
                for: "MoveFitBackendBaseURL",
                infoDictionary: ["MoveFitBackendBaseURL": "https://api.movefitgo.com"],
                requiresProductionHTTPS: true
            ),
            URL(string: "https://api.movefitgo.com")
        )
        for value in [
            "https://replace-before-release.invalid",
            "https://localhost:8000",
            "https://127.0.0.1:8000",
            "https://192.168.31.126:8000",
            "https://10.0.0.8",
            "https://[::1]",
            "http://api.movefitgo.com",
            "https://example.com"
        ] {
            XCTAssertThrowsError(
                try AppEnvironment.url(
                    for: "MoveFitBackendBaseURL",
                    infoDictionary: ["MoveFitBackendBaseURL": value],
                    requiresProductionHTTPS: true
                ),
                "Release 不得接受：\(value)"
            )
        }
    }

    func testGoogleRedirectURIAcceptsRegisteredCustomScheme() throws {
        let redirect = AppEnvironment.googleRedirectURI(infoDictionary: [
            "MoveFitGoogleRedirectURI": "com.movefit.mobile:/oauth2redirect/google",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["com.movefit.mobile"]]]
        ])
        XCTAssertEqual(redirect, URL(string: "com.movefit.mobile:/oauth2redirect/google"))
    }

    func testGoogleRedirectURIRejectsUnregisteredAndWebSchemes() {
        let unregistered = AppEnvironment.googleRedirectURI(infoDictionary: [
            "MoveFitGoogleRedirectURI": "com.other.app:/oauth2redirect/google",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["com.movefit.mobile"]]]
        ])
        XCTAssertNil(unregistered)

        let httpsScheme = AppEnvironment.googleRedirectURI(infoDictionary: [
            "MoveFitGoogleRedirectURI": "https://accounts.example.com/oauth2redirect",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["com.movefit.mobile"]]]
        ])
        XCTAssertNil(httpsScheme)

        let missingTypes = AppEnvironment.googleRedirectURI(infoDictionary: [
            "MoveFitGoogleRedirectURI": "com.movefit.mobile:/oauth2redirect/google"
        ])
        XCTAssertNil(missingTypes)
    }

    func testInitReadsConfigurationFromFixtureBundle() throws {
        let bundle = try makeFixtureBundle(with: [
            "MoveFitBackendBaseURL": "https://api.example.com",
            "MoveFitExerciseBaseURL": "http://10.0.0.5:8001",
            "MoveFitAIBaseURL": "https://ai.example.com",
            "MoveFitGoogleRedirectURI": "com.movefit.mobile:/oauth2redirect/google",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["com.movefit.mobile"]]]
        ])
        let environment = try AppEnvironment(bundle: bundle)
        XCTAssertEqual(environment.backendBaseURL, URL(string: "https://api.example.com"))
        XCTAssertEqual(environment.exerciseBaseURL, URL(string: "http://10.0.0.5:8001"))
        XCTAssertEqual(environment.aiBaseURL, URL(string: "https://ai.example.com"))
        XCTAssertEqual(environment.googleRedirectURI, URL(string: "com.movefit.mobile:/oauth2redirect/google"))
    }

    func testInitThrowsWhenRequiredKeyMissing() throws {
        let bundle = try makeFixtureBundle(with: [
            "MoveFitExerciseBaseURL": "http://10.0.0.5:8001",
            "MoveFitAIBaseURL": "https://ai.example.com"
        ])
        XCTAssertThrowsError(try AppEnvironment(bundle: bundle)) { error in
            XCTAssertEqual(
                error as? AppEnvironmentError,
                .invalidValue("MoveFitBackendBaseURL")
            )
        }
    }

    private func makeFixtureBundle(with info: [String: Any]) throws -> Bundle {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppEnvironmentFixture-\(UUID().uuidString)", isDirectory: true)
        createdFixtureRoots.append(root)
        let bundleURL = root.appendingPathComponent("Env.bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: bundleURL.appendingPathComponent("Info.plist"))
        return try XCTUnwrap(Bundle(url: bundleURL), "测试夹具 bundle 创建失败")
    }
}
