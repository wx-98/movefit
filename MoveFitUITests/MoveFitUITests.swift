import XCTest

final class MoveFitUITests: XCTestCase {
    func testFiveTabsAreReachable() {
        let app = XCUIApplication()
        app.launch()
        for tab in ["首页", "挑战", "运动", "历史", "我的"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 3))
        }
    }

    func testQuickStartOpensWorkoutSession() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(waitForLocalDataLoad(in: app))
        app.tabBars.buttons["运动"].tap()
        XCTAssertTrue(app.buttons["quickStartButton"].waitForExistence(timeout: 3))
        app.buttons["quickStartButton"].staticTexts["快速开始"].tap()
        XCTAssertTrue(app.navigationBars["运动中"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["跑步"].exists)
    }

    func testManualWorkoutCanBeSavedAndHistoryRefreshes() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["运动"].tap()
        XCTAssertTrue(app.buttons["手动记录"].waitForExistence(timeout: 3))
        app.buttons["手动记录"].tap()
        XCTAssertTrue(app.buttons["保存记录"].waitForExistence(timeout: 3))
        app.buttons["保存记录"].tap()
        XCTAssertTrue(app.buttons["手动记录"].waitForExistence(timeout: 3))
        app.tabBars.buttons["历史"].tap()
        XCTAssertTrue(app.staticTexts["最近运动"].waitForExistence(timeout: 3))
    }

    func testDarkModeAndAccessibilityTextSizeKeepNavigationUsable() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleInterfaceStyle", "Dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["首页"].waitForExistence(timeout: 3))
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.navigationBars["我的"].waitForExistence(timeout: 3))
    }

    func testHomeTrendAndSleepDetailsAreReachable() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["healthTrendCard"].waitForExistence(timeout: 5))
        app.buttons["healthTrendCard"].tap()
        XCTAssertTrue(app.navigationBars["健康趋势"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["sleepCard"].waitForExistence(timeout: 3))
        app.buttons["sleepCard"].tap()
        XCTAssertTrue(app.navigationBars["睡眠"].waitForExistence(timeout: 3))
    }

    func testChallengeDetailCanJoinAndWorkoutCatalogIsReachable() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["挑战"].tap()
        XCTAssertTrue(app.buttons["featuredChallengeCard"].waitForExistence(timeout: 5))
        app.buttons["featuredChallengeCard"].tap()
        XCTAssertTrue(app.buttons["challengeJoinButton"].waitForExistence(timeout: 3))

        app.tabBars.buttons["运动"].tap()
        XCTAssertTrue(app.buttons["exerciseCatalogLink"].waitForExistence(timeout: 3))
        app.buttons["exerciseCatalogLink"].tap()
        XCTAssertTrue(app.navigationBars["动作库"].waitForExistence(timeout: 3))
    }

    func testProfileSettingsPagesAreReachable() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["外观与语言"].waitForExistence(timeout: 5))
        app.staticTexts["外观与语言"].tap()
        XCTAssertTrue(app.navigationBars["外观与语言"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["隐私政策"].tap()
        XCTAssertTrue(app.navigationBars["隐私政策"].waitForExistence(timeout: 3))
    }

    func testRealBackendStatusIsVisible() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["后端服务"].waitForExistence(timeout: 5))
        app.staticTexts["后端服务"].tap()
        XCTAssertTrue(app.navigationBars["后端服务"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["backendBaseURLLabel"].exists)
        XCTAssertTrue(app.staticTexts["exerciseBaseURLLabel"].exists)
        XCTAssertTrue(app.staticTexts["aiBaseURLLabel"].exists)
    }

    func testAccountLandingExplainsMethodsAndOpensPasswordFlow() {
        let app = XCUIApplication()
        app.launch()
        let loading = app.staticTexts["正在加载本地数据…"]
        if loading.waitForExistence(timeout: 5) {
            let didFinishLoading = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: loading
            )
            XCTAssertEqual(XCTWaiter.wait(for: [didFinishLoading], timeout: 45), .completed)
        }
        app.tabBars.buttons["我的"].tap()
        let accountButton = app.buttons["账号与登录"]
        XCTAssertTrue(accountButton.waitForExistence(timeout: 5))
        app.scrollViews.firstMatch.swipeUp()
        app.staticTexts["账号与登录"].tap()
        XCTAssertTrue(app.navigationBars["账户"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["欢迎来到 MoveFit"].exists)
        XCTAssertTrue(app.buttons["accountChoosePasswordButton"].exists)
        XCTAssertTrue(app.buttons["accountAppleButton"].exists)
        XCTAssertTrue(app.buttons["accountGoogleButton"].exists)
        XCTAssertTrue(app.buttons["accountWeChatButton"].label.contains("需配置"))
        app.buttons["accountWeChatButton"].tap()
        XCTAssertTrue(app.alerts["提示"].waitForExistence(timeout: 3))
        app.alerts["提示"].buttons["知道了"].tap()
        app.buttons["accountChoosePasswordButton"].tap()
        XCTAssertTrue(app.textFields["registrationIdentifierField"].waitForExistence(timeout: 3))
    }

    func testRegistrationUsesVerificationCodeInsteadOfManualProof() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-registration")
        app.launch()
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["账号与登录"].waitForExistence(timeout: 5))
        app.staticTexts["账号与登录"].tap()
        XCTAssertTrue(app.navigationBars["账户"].waitForExistence(timeout: 3))

        app.buttons["registrationModeButton"].tap()
        XCTAssertTrue(app.segmentedControls["registrationKindPicker"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["手机号需包含国家码，例如 +8613800000000。"].exists)
        XCTAssertFalse(app.textFields["服务端验证证明"].exists)

        let identifier = app.textFields["registrationIdentifierField"]
        XCTAssertTrue(identifier.exists)
        identifier.tap()
        identifier.typeText("tester@example.com")
        let password = app.secureTextFields["registrationPasswordField"]
        XCTAssertTrue(password.exists)
        app.buttons["registrationKeyboardDoneButton"].tap()
        app.buttons["registrationSendCodeButton"].tap()

        XCTAssertTrue(app.textFields["registrationCodeField"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["registrationCooldownLabel"].exists)
        XCTAssertTrue(app.staticTexts["验证码已请求，请检查对应的邮箱或手机号。"].exists)
    }

    func testRateLimitedRegistrationRequestExposesAccessibleCooldown() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-registration",
            "-ui-testing-registration-rate-limit"
        ]
        app.launch()
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["账号与登录"].waitForExistence(timeout: 5))
        app.staticTexts["账号与登录"].tap()
        XCTAssertTrue(app.navigationBars["账户"].waitForExistence(timeout: 3))

        app.buttons["registrationModeButton"].tap()
        let identifier = app.textFields["registrationIdentifierField"]
        XCTAssertTrue(identifier.waitForExistence(timeout: 3))
        identifier.tap()
        identifier.typeText("tester@example.com")
        app.buttons["registrationKeyboardDoneButton"].tap()
        app.buttons["registrationSendCodeButton"].tap()

        let cooldown = app.staticTexts["registrationCooldownLabel"]
        XCTAssertTrue(cooldown.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["registrationSendCodeButton"].isEnabled)
        XCTAssertTrue(app.staticTexts["操作过于频繁，请在 120 秒后重试。"].exists)
    }

    func testHealthMetricDetailAndChallengeCatalogAreReachable() {
        let app = XCUIApplication()
        app.launch()
        let stepsMetric = app.buttons["healthMetric-steps"]
        XCTAssertTrue(
            scrollUntilVisible(stepsMetric, in: app.scrollViews["homeScrollView"])
        )
        stepsMetric.tap()
        XCTAssertTrue(app.navigationBars["步数"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["挑战"].tap()
        XCTAssertTrue(app.staticTexts["服务端挑战"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["本机挑战目录"].exists)
        XCTAssertTrue(app.staticTexts["60/60 项"].exists)
    }

    func testPersonalHealthManagementEntriesAreReachable() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(waitForLocalDataLoad(in: app))
        let symptom = app.buttons["personalHealthLink-symptom"]
        XCTAssertTrue(
            scrollUntilVisible(symptom, in: app.scrollViews["homeScrollView"])
        )
        symptom.staticTexts["症状记录"].tap()
        XCTAssertTrue(app.navigationBars["症状记录"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["savePersonalHealthRecord"].exists)
    }

    private func waitForLocalDataLoad(in app: XCUIApplication) -> Bool {
        let loadingMessage = app.staticTexts["正在加载本地数据…"]
        let finished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: loadingMessage
        )
        return XCTWaiter.wait(for: [finished], timeout: 20) == .completed
    }

    private func scrollUntilVisible(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        maximumSwipes: Int = 6
    ) -> Bool {
        guard scrollView.waitForExistence(timeout: 3) else { return false }
        for _ in 0 ..< maximumSwipes {
            if element.exists && element.isHittable {
                return true
            }
            scrollView.swipeUp()
        }
        return element.waitForExistence(timeout: 3) && element.isHittable
    }

    func testHomeUsesHealthReadingSections() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["今日概览"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["今日活动"].exists)
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(app.staticTexts["重点指标"].exists)
        XCTAssertTrue(app.staticTexts["健康管理"].exists)
    }
}
