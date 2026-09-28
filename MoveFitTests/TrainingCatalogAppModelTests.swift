import XCTest
@testable import MoveFit

final class TrainingCatalogAppModelTests: XCTestCase {
    @MainActor
    func testInitialCatalogUsesRestoredLanguageAndKeepsRemoteEmptyState() async throws {
        let persistence = PersistenceController(inMemory: true)
        try await persistence.saveStringPreference(key: "language", value: AppLanguage.simplifiedChinese.rawValue)
        let catalog = RecordingTrainingCatalog(results: [
            TrainingCatalogResult(plans: [], source: .remote)
        ])
        let model = makeModel(catalog: catalog, persistence: persistence)

        await model.load()
        await waitForCatalogStatus(.empty, in: model)

        let locales = await catalog.locales()
        XCTAssertEqual(locales, ["zh-Hans"])
        XCTAssertEqual(model.trainingCatalogSource, .remote)
        XCTAssertEqual(model.trainingPlans, [])
        XCTAssertNil(model.loadError)
    }

    @MainActor
    func testLanguageChangeRefreshesCatalogUsingSystemEnglishLocale() async throws {
        let persistence = PersistenceController(inMemory: true)
        try await persistence.saveStringPreference(key: "language", value: AppLanguage.simplifiedChinese.rawValue)
        let catalog = RecordingTrainingCatalog(results: [
            TrainingCatalogResult(plans: [Self.plan(title: "中文方案")], source: .remote),
            TrainingCatalogResult(plans: [Self.plan(title: "English plan")], source: .remote)
        ])
        let model = makeModel(catalog: catalog, persistence: persistence)
        await model.load()
        await waitForCatalogStatus(.available, in: model)

        await model.setAppLanguage(.system)

        let locales = await catalog.locales()
        XCTAssertEqual(locales, ["zh-Hans", "en"])
        XCTAssertEqual(model.trainingPlans.map(\.title), ["English plan"])
        XCTAssertEqual(model.trainingCatalogSource, .remote)
    }

    @MainActor
    func testFollowSystemUsesPreferredEnglishForRemoteEmptyCatalog() async {
        let catalog = RecordingTrainingCatalog(results: [
            TrainingCatalogResult(plans: [], source: .remote)
        ])
        let model = makeModel(catalog: catalog, persistence: nil, preferredSystemLanguage: "en-US")

        await model.load()
        await waitForCatalogStatus(.empty, in: model)

        let locales = await catalog.locales()
        XCTAssertEqual(locales, ["en"])
        XCTAssertEqual(model.trainingCatalogSource, .remote)
        XCTAssertTrue(model.trainingPlans.isEmpty)
    }

    @MainActor
    func testRetryReplacesLocalFallbackWithRemoteCatalog() async throws {
        let catalog = RecordingTrainingCatalog(results: [
            TrainingCatalogResult(
                plans: [Self.plan(title: "内置方案")],
                source: .bundledFallback(reason: .unavailable)
            ),
            TrainingCatalogResult(plans: [Self.plan(title: "已发布方案")], source: .remote)
        ])
        let model = makeModel(catalog: catalog, persistence: nil)
        await model.load()
        await waitForCatalogStatus(.bundledFallback, in: model)
        XCTAssertEqual(model.trainingCatalogSource, .bundledFallback(reason: .unavailable))

        await model.reloadTrainingPlans()

        XCTAssertEqual(model.trainingPlans.map(\.title), ["已发布方案"])
        XCTAssertEqual(model.trainingCatalogSource, .remote)
        let locales = await catalog.locales()
        XCTAssertEqual(locales.count, 2)
    }

    @MainActor
    func testCatalogFailureDoesNotBlockLocalData() async {
        let catalog = RecordingTrainingCatalog(results: [], failure: BackendError.networkUnavailable)
        let model = makeModel(catalog: catalog, persistence: nil)

        await model.load()
        await waitForCatalogStatus(.failed, in: model)

        XCTAssertEqual(model.workouts.count, 2)
        XCTAssertNil(model.loadError)
        XCTAssertEqual(model.trainingCatalogStatus, .failed)
    }

    @MainActor
    func testPublicCatalogStillLoadsWhenStoredAccountSessionIsInvalid() async {
        let catalog = RecordingTrainingCatalog(results: [
            TrainingCatalogResult(plans: [Self.plan(title: "公开方案")], source: .remote)
        ])
        let model = makeModel(
            catalog: catalog,
            persistence: nil,
            authenticationProvider: InvalidStoredSessionAuthentication()
        )

        await model.load()
        await waitForCatalogStatus(.available, in: model)

        XCTAssertEqual(model.trainingPlans.map(\.title), ["公开方案"])
    }

    @MainActor
    func testCancelledCatalogLoadRestoresPreviousStatus() async {
        let catalog = RecordingTrainingCatalog(results: [], failure: CancellationError())
        let model = makeModel(catalog: catalog, persistence: nil)

        await model.reloadTrainingPlans()

        XCTAssertEqual(model.trainingCatalogStatus, .notLoaded)
        XCTAssertNil(model.trainingCatalogSource)
    }

    @MainActor
    func testSlowRemoteCatalogDoesNotBlockInitialLocalData() async {
        let requestStarted = expectation(description: "catalog request started")
        let loadFinished = expectation(description: "local app load finished")
        let catalog = BlockingTrainingCatalog(requestStarted: requestStarted)
        let model = makeModel(catalog: catalog, persistence: nil)
        let loadTask = Task {
            await model.load()
            loadFinished.fulfill()
        }

        await fulfillment(of: [requestStarted], timeout: 2)
        await fulfillment(of: [loadFinished], timeout: 1)
        XCTAssertEqual(model.workouts.count, 2)
        await catalog.release()
        await loadTask.value
    }

    @MainActor
    private func makeModel(
        catalog: TrainingCatalogProviding,
        persistence: PersistenceController?,
        authenticationProvider: AuthenticationProviding = UnavailableAuthenticationAdapter(),
        preferredSystemLanguage: String = "en-US"
    ) -> AppModel {
        AppModel(
            workoutRepository: DemoWorkoutRepository(),
            healthProvider: UnavailableTrainingTestHealthProvider(),
            persistenceController: persistence,
            authenticationProvider: authenticationProvider,
            trainingCatalogProvider: catalog,
            preferredSystemLanguage: preferredSystemLanguage
        )
    }

    @MainActor
    private func waitForCatalogStatus(
        _ expected: TrainingCatalogStatus,
        in model: AppModel
    ) async {
        for _ in 0..<100 {
            if model.trainingCatalogStatus == expected { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for training catalog status \(expected)")
    }

    private static func plan(title: String) -> TrainingPlan {
        TrainingPlan(
            id: "00000000-0000-0000-0000-000000000101",
            type: .running,
            title: title,
            subtitle: "测试副标题",
            difficulty: .beginner,
            durationMinutes: 10,
            goal: "完成训练",
            suitableFor: "初学者",
            steps: [TrainingStep(id: "step", title: "跑步", detail: "保持节奏", durationMinutes: 10)],
            safetyNotes: ["注意安全"],
            tint: .blue
        )
    }
}

private struct InvalidStoredSessionAuthentication: AuthenticationProviding {
    func restoreSession() async throws -> AccountSession? { throw BackendError.invalidSession }
    func signIn(kind: AccountIdentifierKind, identifier: String, password: String) async throws
        -> AccountSession { throw BackendError.invalidSession }
    func register(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String,
        verificationProof: String
    ) async throws { throw BackendError.invalidSession }
    func signOut(allSessions: Bool) async {}
}

private actor RecordingTrainingCatalog: TrainingCatalogProviding {
    private var results: [TrainingCatalogResult]
    private let failure: Error?
    private var requestedLocales: [String] = []

    init(results: [TrainingCatalogResult], failure: Error? = nil) {
        self.results = results
        self.failure = failure
    }

    func plans(locale: String) async throws -> TrainingCatalogResult {
        requestedLocales.append(locale)
        if let failure { throw failure }
        guard !results.isEmpty else { throw BackendError.invalidResponse }
        return results.removeFirst()
    }

    func locales() -> [String] { requestedLocales }
}

private struct UnavailableTrainingTestHealthProvider: HealthDataProviding {
    let isAvailable = false
    func requestAuthorization() async throws {}
    func dailySummary() async throws -> HealthSummary? { nil }
}

private actor BlockingTrainingCatalog: TrainingCatalogProviding {
    private let requestStarted: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?

    init(requestStarted: XCTestExpectation) {
        self.requestStarted = requestStarted
    }

    func plans(locale: String) async throws -> TrainingCatalogResult {
        requestStarted.fulfill()
        await withCheckedContinuation { continuation = $0 }
        return TrainingCatalogResult(plans: [], source: .remote)
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
