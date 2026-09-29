import XCTest
@testable import MoveFit

final class AppLocalizerTests: XCTestCase {
    func testRuntimeMessageUsesExplicitEnglishEvenOnChineseDevice() {
        let localizer = AppLocalizer(
            language: .english,
            preferredSystemLanguage: "zh-CN",
            bundle: Bundle(for: AppModel.self)
        )

        XCTAssertEqual(localizer.text("服务暂时不可用，请稍后重试。"), "Service is temporarily unavailable. Please try again later.")
        XCTAssertEqual(localizer.appearanceName(.dark), "Dark")
        XCTAssertEqual(localizer.languageName(.system), "Follow System")
        XCTAssertEqual(localizer.text("首页"), "Home")
        XCTAssertEqual(localizer.text("今日概览"), "Today at a glance")
        XCTAssertEqual(localizer.formatted("home.goal.format", "30 minutes"), "Goal: 30 minutes")
        XCTAssertEqual(localizer.minutes(38), "38 minutes")
        XCTAssertEqual(localizer.minutes(1), "1 minute")
    }

    func testRuntimeMessageAndUnitsSwitchToChineseWithoutGlobalMutation() {
        let localizer = AppLocalizer(
            language: .simplifiedChinese,
            preferredSystemLanguage: "en-US",
            bundle: Bundle(for: AppModel.self)
        )

        XCTAssertEqual(localizer.text("服务暂时不可用，请稍后重试。"), "服务暂时不可用，请稍后重试。")
        XCTAssertEqual(localizer.appearanceName(.dark), "深色")
        XCTAssertEqual(localizer.minutes(38), "38 分钟")
    }

    func testEnglishResourceCoversEveryExistingChineseLocalizationKey() throws {
        let bundle = Bundle(for: AppModel.self)
        let chinesePath = try XCTUnwrap(bundle.path(forResource: "zh-Hans", ofType: "lproj"))
        let englishPath = try XCTUnwrap(bundle.path(forResource: "en", ofType: "lproj"))
        let chinese = try XCTUnwrap(
            NSDictionary(contentsOfFile: chinesePath + "/Localizable.strings") as? [String: String]
        )
        let english = try XCTUnwrap(
            NSDictionary(contentsOfFile: englishPath + "/Localizable.strings") as? [String: String]
        )

        XCTAssertTrue(Set(chinese.keys).isSubset(of: Set(english.keys)))
        XCTAssertFalse(english.values.contains { $0.range(of: "\\p{Han}", options: .regularExpression) != nil })
    }

    func testTrendAndSleepSafetyLabelsUseEnglishResources() {
        let localizer = AppLocalizer(
            language: .english,
            preferredSystemLanguage: "zh-CN",
            bundle: Bundle(for: AppModel.self)
        )

        XCTAssertEqual(localizer.text("睡眠阶段"), "Sleep stages")
        XCTAssertEqual(localizer.text("暂无趋势数据"), "No trend data yet")
        XCTAssertEqual(localizer.duration(seconds: 5_400), "1 hour 30 minutes")
        XCTAssertEqual(localizer.duration(seconds: 3_660), "1 hour 1 minute")
        XCTAssertEqual(
            localizer.text("该评分由 MoveFit 本地规则生成，不是 Apple 官方睡眠评分，也不能用于诊断睡眠障碍。持续不适请咨询专业人员。"),
            "This score uses MoveFit's on-device rules. It is not an official Apple sleep score and cannot diagnose a sleep disorder. Consult a qualified professional if symptoms persist."
        )
    }

    func testHealthMetricSafetyNoticesUseEnglishResources() {
        let localizer = AppLocalizer(
            language: .english,
            preferredSystemLanguage: "zh-CN",
            bundle: Bundle(for: AppModel.self)
        )

        XCTAssertEqual(localizer.text("窦性心律记录"), "Sinus rhythm recording")
        XCTAssertEqual(
            localizer.text("这是设备记录的分类，不替代医疗诊断。"),
            "This is the device's classification, not a medical diagnosis."
        )
        XCTAssertEqual(
            localizer.text("MoveFit 仅在您点按记录后于内存中显示 HealthKit 提供的波形，不保存、上传或分析原始心电图，也不提供诊断。"),
            "MoveFit displays HealthKit's waveform in memory only after you tap a recording. It does not store, upload, or analyze raw ECG data, and does not provide a diagnosis."
        )
    }

    func testWorkoutTypeAndDifficultyKeepStableIDsButRenderEnglish() {
        let localizer = AppLocalizer(
            language: .english,
            preferredSystemLanguage: "zh-CN",
            bundle: Bundle(for: AppModel.self)
        )

        XCTAssertEqual(WorkoutType.strength.rawValue, "力量")
        XCTAssertEqual(TrainingDifficulty.beginner.rawValue, "入门")
        XCTAssertEqual(localizer.text(WorkoutType.strength.rawValue), "Strength")
        XCTAssertEqual(localizer.text(TrainingDifficulty.beginner.rawValue), "Beginner")
        XCTAssertEqual(localizer.formatted("workouts.plan.count.format", 2), "2 plans")
    }

    func testTrainingSafetyDisclaimerUsesEnglishResource() {
        let localizer = AppLocalizer(
            language: .english,
            preferredSystemLanguage: "zh-CN",
            bundle: Bundle(for: AppModel.self)
        )

        XCTAssertEqual(
            localizer.text("内容用于一般运动指导，不能替代医疗诊断或个体化专业建议。"),
            "This content provides general exercise guidance and does not replace medical diagnosis or personalized professional advice."
        )
    }

    func testRuntimeErrorsDoNotFallBackToChineseInEnglishMode() {
        let localizer = AppLocalizer(
            language: .english,
            preferredSystemLanguage: "zh-CN",
            bundle: Bundle(for: AppModel.self)
        )

        XCTAssertEqual(
            localizer.text("运动记录保存失败，请重试。"),
            "Couldn't save the workout. Please try again."
        )
        XCTAssertEqual(
            localizer.text("Apple 健康授权未完成，请在系统设置中检查后重试。"),
            "Apple Health access was not completed. Check Settings and try again."
        )
    }

    func testHistoryPeriodAndTrendComparisonUseEnglishResources() {
        let localizer = AppLocalizer(
            language: .english,
            preferredSystemLanguage: "zh-CN",
            bundle: Bundle(for: AppModel.self)
        )

        XCTAssertEqual(HistoryPeriod.sixMonths.rawValue, "六月")
        XCTAssertEqual(localizer.text(HistoryPeriod.sixMonths.rawValue), "6 months")
        XCTAssertEqual(
            localizer.text("今天步数高于当前周期平均水平。"),
            "Today's steps are above the average for this period."
        )
    }

    func testWorkoutRouteAbsenceExplainsDataLimitInEnglish() {
        let localizer = AppLocalizer(
            language: .english,
            preferredSystemLanguage: "zh-CN",
            bundle: Bundle(for: AppModel.self)
        )

        XCTAssertEqual(
            localizer.text("Apple 健康训练样本未提供可读取路线，时长、距离和能量仍会正常展示。"),
            "The Apple Health workout has no readable route. Duration, distance, and energy remain available."
        )
    }

    func testProfileAccountAndPrivacyLabelsUseEnglishResources() {
        let localizer = AppLocalizer(
            language: .english,
            preferredSystemLanguage: "zh-CN",
            bundle: Bundle(for: AppModel.self)
        )

        XCTAssertEqual(localizer.text("隐私与缓存"), "Privacy and cache")
        XCTAssertEqual(localizer.text(AuthenticationMethod.phone.rawValue), "Phone")
        XCTAssertEqual(
            localizer.formatted("profile.server.session.format", "Phone", "Avery"),
            "Phone server session · Avery"
        )
    }
}
