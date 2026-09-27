import CoreLocation
import XCTest
@testable import MoveFit

final class MoveFitTests: XCTestCase {
    func testActivityAggregationIgnoresNegativeSteps() {
        let aggregator = ActivityAggregator()
        XCTAssertEqual(aggregator.totalSteps([5_000, -100, 7_000]), 12_000)
        XCTAssertEqual(aggregator.averageDailySteps([5_000, -100, 7_000]), 4_000)
        XCTAssertEqual(aggregator.averageDailySteps([]), 0)
    }

    func testChallengeProgressIsClampedToValidRange() {
        let calculator = ChallengeProgressCalculator()
        XCTAssertEqual(calculator.ratio(progress: 75, goal: 100), 0.75)
        XCTAssertEqual(calculator.ratio(progress: 150, goal: 100), 1)
        XCTAssertEqual(calculator.ratio(progress: -10, goal: 100), 0)
        XCTAssertEqual(calculator.ratio(progress: 10, goal: 0), 0)
    }

    func testWellnessRulesRecommendActivityAndStandBreak() {
        let summary = HealthSummary(
            activeEnergy: Measurement(value: 100, unit: .kilocalories),
            exerciseMinutes: 12,
            standHours: 4,
            steps: 2_000,
            distance: Measurement(value: 1.2, unit: .kilometers),
            heartRate: nil,
            restingHeartRate: nil
        )
        XCTAssertEqual(
            WellnessRuleEngine().recommendations(for: summary),
            [.increaseActivity, .addStandBreak]
        )
    }

    func testWorkoutStateMachineRejectsInvalidTransition() {
        var machine = WorkoutSessionStateMachine()
        XCTAssertFalse(machine.send(.finish))
        XCTAssertEqual(machine.state, .idle)
    }

    func testWorkoutStateMachineCompletesSession() {
        var machine = WorkoutSessionStateMachine()
        let id = UUID()
        XCTAssertTrue(machine.send(.prepare(.running)))
        XCTAssertTrue(machine.send(.start(Date())))
        XCTAssertTrue(machine.send(.pause(60)))
        XCTAssertTrue(machine.send(.finish))
        XCTAssertTrue(machine.send(.saved(id)))
        XCTAssertEqual(machine.state, .completed(id))
    }

    func testWorkoutStateMachineCanAbandonActiveSession() {
        var machine = WorkoutSessionStateMachine()
        XCTAssertTrue(machine.send(.prepare(.running)))
        XCTAssertTrue(machine.send(.start(Date())))
        XCTAssertTrue(machine.send(.cancel))
        XCTAssertEqual(machine.state, .idle)
    }

    func testMetricDistanceFormatting() {
        XCTAssertEqual(AppFormat.distance(Measurement(value: 5, unit: .kilometers)), "5.0 公里")
    }

    func testDemoRepositoryIsIdempotent() async throws {
        let repository = DemoWorkoutRepository()
        let operationID = UUID()
        let workout = makeWorkout()
        try await repository.save(workout, operationID: operationID)
        try await repository.save(workout, operationID: operationID)
        let savedWorkouts = try await repository.workouts()
        XCTAssertEqual(savedWorkouts.filter { $0.id == workout.id }.count, 1)
    }

    func testInMemoryCoreDataPersistsProfileAndWorkout() async throws {
        let persistence = PersistenceController(inMemory: true)
        let profile = UserProfile(
            nickname: "本地测试用户",
            height: Measurement(value: 168, unit: .centimeters),
            weight: Measurement(value: 58, unit: .kilograms),
            bodyFatPercentage: 20
        )
        let workout = makeWorkout()
        try await persistence.save(profile: profile)
        try await persistence.save(workout: workout, operationID: UUID())

        let savedProfile = try await persistence.loadProfile()
        let workouts = try await persistence.loadWorkouts()
        XCTAssertEqual(savedProfile?.nickname, "本地测试用户")
        XCTAssertEqual(workouts.map(\.id), [workout.id])
    }

    func testCoreDataOperationIsIdempotentAndCacheCanBeCleared() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = DemoWorkoutRepository(persistenceController: persistence)
        let workout = makeWorkout()
        let operationID = UUID()
        try await repository.save(workout, operationID: operationID)
        try await repository.save(workout, operationID: operationID)

        let initialWorkoutCount = try await persistence.loadWorkouts().count
        let initialOperationCount = try await persistence.offlineOperationCount()
        XCTAssertEqual(initialWorkoutCount, 1)
        XCTAssertEqual(initialOperationCount, 1)
        try await persistence.clearRebuildableCache()
        let clearedOperationCount = try await persistence.offlineOperationCount()
        let retainedWorkoutCount = try await persistence.loadWorkouts().count
        XCTAssertEqual(clearedOperationCount, 0)
        XCTAssertEqual(retainedWorkoutCount, 1)
    }

    func testCoreDataRepositoryStartsEmptyAndPersistsOnlyUserWorkout() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = CoreDataWorkoutRepository(persistenceController: persistence)
        let initialWorkouts = try await repository.workouts()
        XCTAssertTrue(initialWorkouts.isEmpty)

        let workout = makeWorkout()
        try await repository.save(workout, operationID: UUID())
        let savedWorkoutIDs = try await repository.workouts().map(\.id)
        XCTAssertEqual(savedWorkoutIDs, [workout.id])
    }

    func testCoreDataRestoresChallengeArticleAndPrivacyState() async throws {
        let persistence = PersistenceController(inMemory: true)
        let challengeID = UUID()
        let articleID = UUID()
        try await persistence.saveChallenge(id: challengeID, isJoined: true)
        try await persistence.saveArticle(id: articleID, isFavorite: true)
        try await persistence.savePreference(key: "hidesSensitiveMetrics", value: true)

        let joinedIDs = try await persistence.loadJoinedChallengeIDs()
        let favoriteIDs = try await persistence.loadFavoriteArticleIDs()
        let preference = try await persistence.loadPreference(key: "hidesSensitiveMetrics")
        XCTAssertEqual(joinedIDs, [challengeID])
        XCTAssertEqual(favoriteIDs, [articleID])
        XCTAssertEqual(preference, true)
    }

    func testPersonalHealthStatisticsAndTrendUseOnlyLocalRecords() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let records = [
            PersonalHealthRecord(
                id: UUID(), category: .symptom, occurredAt: now, title: "头痛", detail: "午后", primaryValue: 6,
                secondaryValue: nil, tertiaryValue: nil, isCompleted: false
            ),
            PersonalHealthRecord(
                id: UUID(), category: .medication, occurredAt: now, title: "维生素", detail: "早餐后", primaryValue: nil,
                secondaryValue: nil, tertiaryValue: nil, isCompleted: true
            ),
            PersonalHealthRecord(
                id: UUID(), category: .medication, occurredAt: now, title: "医嘱药品", detail: "晚餐后", primaryValue: nil,
                secondaryValue: nil, tertiaryValue: nil, isCompleted: false
            ),
            PersonalHealthRecord(
                id: UUID(), category: .nutrition, occurredAt: now, title: "午餐", detail: "", primaryValue: 620,
                secondaryValue: 30, tertiaryValue: 70, isCompleted: false
            )
        ]

        let statistics = PersonalHealthStatistics.make(records: records, calendar: calendar, now: now)
        XCTAssertEqual(statistics.symptomAverageSeverity, 6)
        XCTAssertEqual(statistics.medicationAdherence, 0.5)
        XCTAssertEqual(statistics.nutritionCalories, 620)
        XCTAssertEqual(PersonalHealthTrendPoint.make(
            category: .nutrition, records: records, calendar: calendar, now: now
        ).last?.value, 620)
        XCTAssertTrue(PersonalHealthInsightEngine.message(
            for: .symptom, records: records, statistics: statistics
        ).contains("不是诊断"))
    }

    func testCoreDataPersistsUpdatesAndDeletesPersonalHealthRecords() async throws {
        let persistence = PersistenceController(inMemory: true)
        let id = UUID()
        let initial = PersonalHealthRecord(
            id: id, category: .medication, occurredAt: Date(), title: "测试药品", detail: "睡前", primaryValue: 1,
            secondaryValue: nil, tertiaryValue: nil, isCompleted: false
        )
        let completed = PersonalHealthRecord(
            id: id, category: .medication, occurredAt: initial.occurredAt, title: initial.title, detail: initial.detail,
            primaryValue: initial.primaryValue, secondaryValue: nil, tertiaryValue: nil, isCompleted: true
        )
        try await persistence.savePersonalHealthRecord(initial)
        try await persistence.savePersonalHealthRecord(completed)
        let savedRecords = try await persistence.personalHealthRecords()
        XCTAssertEqual(savedRecords, [completed])

        try await persistence.deletePersonalHealthRecord(id: id)
        let remainingRecords = try await persistence.personalHealthRecords()
        XCTAssertTrue(remainingRecords.isEmpty)
    }

    func testECGWaveformDownsamplingKeepsAControlledInMemorySampleCount() {
        let samples = (0 ..< 1_000).map { Double($0) }
        let waveform = ECGWaveform.downsample(recordID: UUID(), samples: samples, maximumCount: 120)
        XCTAssertEqual(waveform.samplesInMicrovolts.count, 120)
        XCTAssertEqual(waveform.samplesInMicrovolts.first, 0)
        XCTAssertEqual(waveform.samplesInMicrovolts.last, 999)
    }

    @MainActor
    func testECGWaveformEmptyResultShowsAVisibleUnavailableMessage() async {
        let recordID = UUID()
        let model = AppModel(
            workoutRepository: DemoWorkoutRepository(),
            healthProvider: EmptyECGWaveformHealthProvider()
        )

        await model.loadElectrocardiogramWaveform(recordID: recordID)

        XCTAssertEqual(model.selectedElectrocardiogramID, recordID)
        XCTAssertNil(model.electrocardiogramWaveform)
        XCTAssertFalse(model.electrocardiogramWaveformMessage?.isEmpty ?? true)
    }

    func testRouteAccumulatorFiltersNoiseAndAccumulatesDistance() {
        var accumulator = RouteAccumulator()
        let startDate = Date()
        accumulator.append(makeLocation(latitude: 31.2304, longitude: 121.4737, date: startDate))
        accumulator.append(
            makeLocation(
                latitude: 31.2305,
                longitude: 121.4738,
                accuracy: 100,
                date: startDate.addingTimeInterval(1)
            )
        )
        accumulator.append(
            makeLocation(
                latitude: 31.2310,
                longitude: 121.4743,
                date: startDate.addingTimeInterval(2)
            )
        )

        XCTAssertEqual(accumulator.summary.route.count, 2)
        XCTAssertGreaterThan(accumulator.summary.distance?.value ?? 0, 2)
    }

    @MainActor
    func testCompletedOutdoorSessionPersistsRealLocationSummary() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = CoreDataWorkoutRepository(persistenceController: persistence)
        let location = StubLocationProvider(
            summary: WorkoutLocationSummary(
                route: [CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)],
                distance: Measurement(value: 800, unit: .meters)
            )
        )
        let model = AppModel(
            workoutRepository: repository,
            healthProvider: UnavailableHealthProvider(),
            locationProvider: location,
            persistenceController: persistence
        )
        model.prepare(.running)
        XCTAssertTrue(model.startSession(type: .running))
        let didComplete = await model.completeSession(type: .running, duration: 60)
        XCTAssertTrue(didComplete)

        let workout = try await repository.workouts().first
        XCTAssertEqual(workout?.distance?.converted(to: .meters).value, 800)
        XCTAssertEqual(workout?.route.count, 1)
        XCTAssertTrue(location.didStart)
        XCTAssertTrue(location.didStop)
    }

    @MainActor
    func testUnavailableHealthPlatformFallsBackWithoutBlockingLocalData() async {
        let model = AppModel(
            workoutRepository: DemoWorkoutRepository(),
            healthProvider: UnavailableHealthProvider()
        )
        await model.load()
        XCTAssertEqual(model.workouts.count, 2)
        XCTAssertNil(model.health.steps)
        XCTAssertEqual(model.healthStatus, .unavailable)
        XCTAssertNil(model.loadError)
    }

    func testProfileValidationRejectsOutOfRangeMetrics() {
        XCTAssertThrowsError(
            try ProfileInputValidator().validate(
                nickname: "用户",
                heightCentimeters: 30,
                weightKilograms: 60,
                bodyFatPercentage: 20
            )
        ) { error in
            XCTAssertEqual(error as? ProfileValidationError, .invalidHeight)
        }
    }

    func testHealthTrendComputesRealAvailablePointStatistics() {
        let start = Date(timeIntervalSince1970: 1_000)
        let trend = HealthTrend(
            metric: .steps,
            period: .week,
            points: [
                HealthTrendPoint(date: start, value: 6_000),
                HealthTrendPoint(date: start.addingTimeInterval(86_400), value: nil),
                HealthTrendPoint(date: start.addingTimeInterval(172_800), value: 10_000)
            ]
        )

        XCTAssertEqual(trend.total, 16_000)
        XCTAssertEqual(trend.average, 8_000)
        XCTAssertEqual(trend.bestPoint?.value, 10_000)
        XCTAssertEqual(trend.availablePoints.count, 2)
    }

    func testChallengeCatalogContainsStableLayeredChallenges() {
        let first = ChallengeCatalog().challenges()
        let second = ChallengeCatalog().challenges()

        XCTAssertEqual(first.count, 60)
        XCTAssertEqual(Set(first.map(\.id)).count, 60)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(Set(first.map(\.category)), Set(ChallengeCategory.allCases))
        XCTAssertTrue(first.contains { $0.title == "减脂 5K" })
        XCTAssertTrue(first.contains { $0.title == "比赛 5K" })
        XCTAssertTrue(first.contains { $0.id == legacyChallengeID(1) && $0.title == "本周 10 万步" })
        XCTAssertTrue(first.contains { $0.id == legacyChallengeID(2) && $0.title == "5K 入门" })
        XCTAssertTrue(first.contains { $0.id == legacyChallengeID(3) && $0.title == "力量 14 日" })
    }

    func testHistoryTrendBucketerUsesMonthBucketsForYear() {
        var calendar = Calendar(identifier: .gregorian)
        guard let timeZone = TimeZone(secondsFromGMT: 0) else {
            return XCTFail("无法创建 UTC 时区")
        }
        calendar.timeZone = timeZone
        let start = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? .distantPast
        let points = (0..<365).compactMap { offset -> HealthTrendPoint? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return HealthTrendPoint(date: date, value: 1_000)
        }
        let buckets = HistoryTrendBucketer().buckets(
            for: HealthTrend(metric: .steps, period: .year, points: points),
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(buckets.count, 12)
        XCTAssertEqual(buckets.first?.value, 31_000)
        XCTAssertEqual(buckets.last?.value, 31_000)
    }

    func testHistoryTrendComparisonDoesNotInferWithoutTodayValue() {
        var calendar = Calendar(identifier: .gregorian)
        guard let timeZone = TimeZone(secondsFromGMT: 0) else {
            return XCTFail("无法创建 UTC 时区")
        }
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8)) ?? Date()
        let prior = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let comparison = HistoryTrendComparison(
            points: [HealthTrendPoint(date: prior, value: 8_000)],
            calendar: calendar,
            timeZone: timeZone,
            now: now
        )

        XCTAssertEqual(comparison.message, "数据不足，暂不能比较今天与平均水平。")
    }

    func testLocalInsightUsesOnlyMetricAggregateRequest() async throws {
        let request = HealthInsightRequest(
            metric: .heartRate,
            currentValue: 72,
            averageValue: 68,
            unit: "BPM",
            period: .month,
            generatedAt: Date(timeIntervalSince1970: 0)
        )
        let provider = LocalHealthInsightProvider()
        let insights = try await provider.analyze(request)
        let access = await provider.access(for: .heartRate)

        XCTAssertEqual(access, .localOnly)
        XCTAssertEqual(insights.first?.source, .localRule)
        XCTAssertFalse(insights.first?.message.contains("诊断") ?? true)
        XCTAssertTrue(insights.first?.safetyNotice.contains("医疗专业人员") ?? false)
    }

    func testSleepScoreUsesDurationEfficiencyAndRegularity() {
        let score = SleepScoreCalculator().score(
            totalSleep: 8 * 3_600,
            timeInBed: 8.5 * 3_600,
            bedtimeDeviationMinutes: 0
        )
        XCTAssertEqual(score, 99)
        XCTAssertNil(
            SleepScoreCalculator().score(
                totalSleep: 0,
                timeInBed: 8 * 3_600,
                bedtimeDeviationMinutes: 0
            )
        )
    }

    func testSleepSummaryMergesOverlappingStageIntervals() {
        let start = Date(timeIntervalSince1970: 10_000)
        let summary = SleepSummaryBuilder().makeSummary(
            segments: [
                SleepStageSegment(
                    id: UUID(),
                    startDate: start,
                    endDate: start.addingTimeInterval(3_600),
                    stage: .core
                ),
                SleepStageSegment(
                    id: UUID(),
                    startDate: start.addingTimeInterval(1_800),
                    endDate: start.addingTimeInterval(5_400),
                    stage: .core
                )
            ]
        )
        XCTAssertEqual(summary?.totalSleep, 5_400)
        XCTAssertEqual(summary?.coreDuration, 5_400)
    }

    func testWorkoutMergerKeepsSameUUIDFromDifferentSourcesAndDeduplicatesWithinSource() {
        let id = UUID()
        let local = makeWorkout(id: id, source: .moveFit)
        let duplicateLocal = makeWorkout(id: id, source: .moveFit)
        let health = makeWorkout(id: id, source: .appleHealth)
        let merged = WorkoutMerger().merge(local: [local, duplicateLocal], health: [health])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(Set(merged.map(\.source.rawValue)), [WorkoutDataSource.moveFit.rawValue, WorkoutDataSource.appleHealth.rawValue])
    }

    func testBundledExerciseCatalogSupportsSearchAndDifficultyFilter() async throws {
        let page = try await BundledExerciseCatalog().exercises(
            query: ExerciseCatalogQuery(text: "深蹲", equipment: nil, muscle: nil, difficulty: .beginner),
            page: 0,
            pageSize: 20
        )
        XCTAssertEqual(page.exercises.map(\.name), ["自重深蹲"])
        XCTAssertEqual(page.sourceVersion, "bundled-zh-CN-1")
        XCTAssertFalse(page.hasMore)
    }

    func testCoreDataPersistsAppearanceAndLanguagePreferences() async throws {
        let persistence = PersistenceController(inMemory: true)
        try await persistence.saveStringPreference(key: "appearance", value: AppAppearance.dark.rawValue)
        try await persistence.saveStringPreference(key: "language", value: AppLanguage.simplifiedChinese.rawValue)
        let appearance = try await persistence.loadStringPreference(key: "appearance")
        let language = try await persistence.loadStringPreference(key: "language")
        XCTAssertEqual(appearance, AppAppearance.dark.rawValue)
        XCTAssertEqual(language, AppLanguage.simplifiedChinese.rawValue)
    }

    @MainActor
    func testDashboardWeeklyStepsRemainStableWhenDetailTrendChanges() async {
        let model = AppModel(
            workoutRepository: DemoWorkoutRepository(),
            healthProvider: StubTrendHealthProvider()
        )
        await model.load()
        XCTAssertEqual(model.weeklyStepTrend.total, 7_000)

        await model.loadTrend(metric: .distance, period: .month)
        XCTAssertEqual(model.healthTrend.metric, .distance)
        XCTAssertEqual(model.healthTrend.total, 5)
        XCTAssertEqual(model.weeklyStepTrend.metric, .steps)
        XCTAssertEqual(model.weeklyStepTrend.total, 7_000)
    }

    private func legacyChallengeID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }

    private func makeWorkout(
        id: UUID = UUID(),
        source: WorkoutDataSource = .moveFit
    ) -> WorkoutRecord {
        WorkoutRecord(
            id: id,
            type: .walking,
            startedAt: Date(),
            duration: 60,
            distance: Measurement(value: 1, unit: .kilometers),
            energy: nil,
            route: [],
            source: source
        )
    }

    private func makeLocation(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        accuracy: CLLocationAccuracy = 5,
        date: Date
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 5,
            timestamp: date
        )
    }
}

private struct UnavailableHealthProvider: HealthDataProviding {
    let isAvailable = false
    func requestAuthorization() async throws {}
    func dailySummary() async throws -> HealthSummary? { nil }
}

private struct StubTrendHealthProvider: HealthDataProviding {
    let isAvailable = true
    func requestAuthorization() async throws {}
    func dailySummary() async throws -> HealthSummary? { nil }
    func trend(metric: HealthTrendMetric, period: HealthTrendPeriod) async throws -> HealthTrend {
        HealthTrend(
            metric: metric,
            period: period,
            points: [HealthTrendPoint(date: Date(), value: metric == .steps ? 7_000 : 5)]
        )
    }
}

private struct EmptyECGWaveformHealthProvider: HealthDataProviding {
    let isAvailable = true
    func requestAuthorization() async throws {}
    func dailySummary() async throws -> HealthSummary? { nil }
    func electrocardiogramWaveform(for recordID: UUID) async throws -> ECGWaveform? { nil }
}

private final class StubLocationProvider: LocationProviding {
    let authorizationStatus = CLAuthorizationStatus.authorizedWhenInUse
    private let storedSummary: WorkoutLocationSummary
    private(set) var didStart = false
    private(set) var didStop = false

    init(summary: WorkoutLocationSummary = .empty) {
        storedSummary = summary
    }

    func requestWhenInUseAuthorization() {}
    func start() { didStart = true }
    func pause() {}
    func resume() {}
    func snapshot() -> WorkoutLocationSummary { storedSummary }
    func stop() -> WorkoutLocationSummary {
        didStop = true
        return storedSummary
    }
}
