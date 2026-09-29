import XCTest
@testable import MoveFit

final class AppLanguageTests: XCTestCase {
    func testFollowSystemUsesFirstSupportedEnglishPreference() {
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredSystemLanguage: "en-US"), "en")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredSystemLanguage: "zh-Hans-CN"), "zh-Hans")
    }

    func testExplicitLanguageOverridesDeviceLanguageWithoutChangingStoredIdentifiers() {
        XCTAssertEqual(AppLanguage(rawValue: "跟随系统"), .system)
        XCTAssertEqual(AppLanguage(rawValue: "简体中文"), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.english.resolvedIdentifier(preferredSystemLanguage: "zh-CN"), "en")
        XCTAssertEqual(AppLanguage.simplifiedChinese.resolvedIdentifier(preferredSystemLanguage: "en-US"), "zh-Hans")
    }

    func testEnglishLocalizationResourceIsBundled() {
        let appBundle = Bundle(for: AppModel.self)
        XCTAssertNotNil(appBundle.path(forResource: "en", ofType: "lproj"))
    }
}
