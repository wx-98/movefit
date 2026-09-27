import CoreLocation
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var health = HealthSummary.empty
    @Published private(set) var healthStatus = HealthDataStatus.notLoaded
    @Published private(set) var healthTrend = HealthTrend.empty(metric: .steps, period: .week)
    @Published private(set) var weeklyStepTrend = HealthTrend.empty(metric: .steps, period: .week)
    @Published private(set) var healthTrendStatus = HealthDataStatus.notLoaded
    @Published private(set) var sleepSummary: SleepSummary?
    @Published private(set) var sleepStatus = HealthDataStatus.notLoaded
    @Published private(set) var workouts: [WorkoutRecord] = []
    @Published private(set) var challenges: [Challenge]
    @Published private(set) var articles: [WellnessArticle]
    @Published private(set) var profile: UserProfile?
    @Published var session = WorkoutSessionStateMachine()
    @Published private(set) var workoutDistance: Measurement<UnitLength>?
    @Published var alertMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    @Published private(set) var accountSession: AccountSession?
    @Published private(set) var hidesSensitiveMetrics = false
    @Published private(set) var trainingPlans: [TrainingPlan] = []
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var exerciseCatalogStatus = ExerciseCatalogStatus.loading
    @Published private(set) var exerciseCatalogMessage: String?
    @Published private(set) var canLoadMoreExercises = false
    @Published private(set) var isLoadingMoreExercises = false
    @Published private(set) var backendConnectionStatus = BackendConnectionStatus.notLoaded
    @Published private(set) var remoteWorkoutMessage: String?
    @Published private(set) var accountOperationInProgress = false
    @Published private(set) var appearance = AppAppearance.system
    @Published private(set) var appLanguage = AppLanguage.system
    @Published private(set) var healthMetricDetail: HealthMetricDetail?
    @Published private(set) var healthMetricDetailStatus = HealthMetricDetailStatus.idle
    @Published private(set) var electrocardiograms: [ECGRecordSummary] = []
    @Published private(set) var electrocardiogramWaveform: ECGWaveform?
    @Published private(set) var electrocardiogramWaveformLoading = false
    @Published private(set) var selectedElectrocardiogramID: UUID?
    @Published private(set) var electrocardiogramWaveformMessage: String?
    @Published private(set) var healthInsights: [HealthInsight] = []
    @Published private(set) var healthInsightAccess = HealthInsightAccess.localOnly
    @Published private(set) var personalHealthRecords: [PersonalHealthRecord] = []
    let remoteFeatures: RemoteFeatureViewModel

    var badges: [Badge] {
        let calendar = Calendar.current
        let activeDays = Set(workouts.map { calendar.startOfDay(for: $0.startedAt) }).count
        let hasFiveKilometerRun = workouts.contains {
            $0.type == .running && ($0.distance?.converted(to: .kilometers).value ?? 0) >= 5
        }
        let cyclingKilometers = workouts
            .filter { $0.type == .cycling }
            .compactMap { $0.distance?.converted(to: .kilometers).value }
            .reduce(0, +)
        return [
            Badge(id: StableID.firstFiveK, title: "首次 5K", symbol: hasFiveKilometerRun ? "star.fill" : "lock.fill", isUnlocked: hasFiveKilometerRun),
            Badge(id: StableID.sevenActiveDays, title: "累计七天", symbol: activeDays >= 7 ? "flame.fill" : "lock.fill", isUnlocked: activeDays >= 7),
            Badge(id: StableID.hundredKilometerCycling, title: "百公里骑行", symbol: cyclingKilometers >= 100 ? "bicycle" : "lock.fill", isUnlocked: cyclingKilometers >= 100)
        ]
    }

    var wellnessRecommendations: [WellnessRecommendation] {
        WellnessRuleEngine().recommendations(for: health)
    }

    var locationAuthorizationStatus: CLAuthorizationStatus {
        locationProvider.authorizationStatus
    }

    private let workoutRepository: WorkoutRepository
    private let healthProvider: HealthDataProviding
    private let locationProvider: LocationProviding
    private let dateProvider: DateProviding
    private let uuidProvider: UUIDProviding
    private let persistenceController: PersistenceController?
    private let authenticationProvider: AuthenticationProviding
    private let socialIdentityProvider: SocialIdentityProviding?
    private let appleAuthorizationProvider: SocialAuthorizationCodeProviding
    private let wechatAuthorizationProvider: SocialAuthorizationCodeProviding
    private let googleOAuthAdapter: GoogleOAuthAdapter?
    private let installationIdentity: InstallationIdentifying
    private let remoteProfileProvider: RemoteProfileProviding?
    private let remoteWorkoutProvider: RemoteWorkoutProviding?
    private let clientConfigurationProvider: ClientConfigurationProviding?
    private let trainingCatalogProvider: TrainingCatalogProviding
    private let exerciseCatalogProvider: ExerciseCatalogProviding
    private let healthInsightProvider: AIHealthInsightProviding
    private let personalHealthRecordProvider: PersonalHealthRecordProviding?
    private let localHealthInsightProvider = LocalHealthInsightProvider()
    private var localWorkouts: [WorkoutRecord] = []
    private var healthWorkouts: [WorkoutRecord] = []
    private var remoteWorkouts: [WorkoutRecord] = []
    private var remoteProfileVersion: Int?
    private var exerciseQuery = ExerciseCatalogQuery()
    private var exercisePage = 0
    private var pendingSocialLinks: [SocialProvider: SocialLinkAttempt] = [:]
    private var pendingSocialUnlinks: [SocialProvider: UUID] = [:]

    init(
        workoutRepository: WorkoutRepository,
        healthProvider: HealthDataProviding,
        locationProvider: LocationProviding = LocationAdapter(),
        dateProvider: DateProviding = SystemDateProvider(),
        uuidProvider: UUIDProviding = SystemUUIDProvider(),
        persistenceController: PersistenceController? = nil,
        authenticationProvider: AuthenticationProviding = UnavailableAuthenticationAdapter(),
        socialIdentityProvider: SocialIdentityProviding? = nil,
        appleAuthorizationProvider: SocialAuthorizationCodeProviding? = nil,
        wechatAuthorizationProvider: SocialAuthorizationCodeProviding? = nil,
        googleOAuthAdapter: GoogleOAuthAdapter? = nil,
        installationIdentity: InstallationIdentifying = KeychainInstallationIdentity(),
        remoteProfileProvider: RemoteProfileProviding? = nil,
        remoteWorkoutProvider: RemoteWorkoutProviding? = nil,
        clientConfigurationProvider: ClientConfigurationProviding? = nil,
        trainingCatalogProvider: TrainingCatalogProviding = BundledTrainingCatalog(),
        exerciseCatalogProvider: ExerciseCatalogProviding = BundledExerciseCatalog(),
        healthInsightProvider: AIHealthInsightProviding = LocalHealthInsightProvider(),
        personalHealthRecordProvider: PersonalHealthRecordProviding? = nil,
        remoteFeatures: RemoteFeatureViewModel? = nil
    ) {
        self.workoutRepository = workoutRepository
        self.healthProvider = healthProvider
        self.locationProvider = locationProvider
        self.dateProvider = dateProvider
        self.uuidProvider = uuidProvider
        self.persistenceController = persistenceController
        self.authenticationProvider = authenticationProvider
        self.socialIdentityProvider = socialIdentityProvider
        self.appleAuthorizationProvider = appleAuthorizationProvider ?? AppleAuthorizationCodeAdapter()
        self.wechatAuthorizationProvider = wechatAuthorizationProvider ?? UnavailableWechatAuthorizationAdapter()
        self.googleOAuthAdapter = googleOAuthAdapter
        self.installationIdentity = installationIdentity
        self.remoteProfileProvider = remoteProfileProvider
        self.remoteWorkoutProvider = remoteWorkoutProvider
        self.clientConfigurationProvider = clientConfigurationProvider
        self.trainingCatalogProvider = trainingCatalogProvider
        self.exerciseCatalogProvider = exerciseCatalogProvider
        self.healthInsightProvider = healthInsightProvider
        self.personalHealthRecordProvider = personalHealthRecordProvider ?? persistenceController
        self.remoteFeatures = remoteFeatures ?? RemoteFeatureViewModel()
        challenges = ChallengeCatalog().challenges()
        articles = Self.defaultArticles
    }

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            localWorkouts = try await workoutRepository.workouts()
            trainingPlans = try await trainingCatalogProvider.plans()
            mergeWorkouts()
            if let persistenceController {
                if let storedProfile = try await persistenceController.loadProfile() {
                    profile = storedProfile
                }
                let joinedIDs = try await persistenceController.loadJoinedChallengeIDs()
                challenges.indices.forEach { challenges[$0].isJoined = joinedIDs.contains(challenges[$0].id) }
                let favoriteIDs = try await persistenceController.loadFavoriteArticleIDs()
                articles.indices.forEach { articles[$0].isFavorite = favoriteIDs.contains(articles[$0].id) }
                hidesSensitiveMetrics = try await persistenceController.loadPreference(
                    key: PreferenceKey.hidesSensitiveMetrics
                ) ?? false
                if let storedAppearance = try await persistenceController.loadStringPreference(
                    key: PreferenceKey.appearance
                ).flatMap(AppAppearance.init(rawValue:)) {
                    appearance = storedAppearance
                }
                if let storedLanguage = try await persistenceController.loadStringPreference(
                    key: PreferenceKey.language
                ).flatMap(AppLanguage.init(rawValue:)) {
                    appLanguage = storedLanguage
                }
            }
            personalHealthRecords = try await personalHealthRecordProvider?.personalHealthRecords() ?? []
            updateDerivedData()
            accountSession = try await authenticationProvider.restoreSession()
            Task {
                await loadExercises(query: ExerciseCatalogQuery())
                await loadBackendConfiguration()
            }
            let locale = contentLocale
            Task { [remoteFeatures] in
                await remoteFeatures.refreshPublic(locale: locale)
            }
            if accountSession != nil {
                Task { await loadRemoteAccountData() }
            } else {
                await remoteFeatures.refreshPrivate(isAuthenticated: false, locale: contentLocale)
            }
        } catch {
            loadError = "本地数据读取失败，请稍后重试。"
            alertMessage = loadError
        }
        await loadHealthData()
    }

    func loadExercises(query: ExerciseCatalogQuery) async {
        exerciseCatalogStatus = .loading
        exerciseCatalogMessage = nil
        exerciseQuery = query
        exercisePage = 0
        do {
            let catalogPage = try await exerciseCatalogProvider.exercises(query: query, page: 0, pageSize: 50)
            exercises = catalogPage.exercises
            canLoadMoreExercises = catalogPage.hasMore
            switch catalogPage.source {
            case .remote:
                exerciseCatalogStatus = .available(version: catalogPage.sourceVersion)
            case let .bundledFallback(message):
                exerciseCatalogStatus = .bundledOnly
                exerciseCatalogMessage = message
            }
        } catch {
            exercises = []
            canLoadMoreExercises = false
            exerciseCatalogStatus = .failed
            exerciseCatalogMessage = error.localizedDescription
        }
    }

    func loadHealthMetricDetail(_ metric: HomeHealthMetric) async {
        guard healthProvider.isAvailable else {
            healthMetricDetail = nil
            electrocardiograms = []
            healthInsights = []
            healthMetricDetailStatus = .unavailable
            return
        }
        healthMetricDetailStatus = .loading
        healthInsights = []
        electrocardiograms = []
        do {
            guard let detail = try await healthProvider.metricDetail(for: metric) else {
                healthMetricDetail = nil
                healthMetricDetailStatus = .noData
                return
            }
            healthMetricDetail = detail
            healthMetricDetailStatus = detail.currentValue == nil && detail.trend.availablePoints.isEmpty
                ? .noData
                : .available
            if metric == .heartRate || metric == .restingHeartRate {
                // ECG 摘要是增强信息；其读取失败不应遮蔽已成功读取的心率数据。
                electrocardiograms = (try? await healthProvider.electrocardiogramSummaries()) ?? []
            }
            await loadHealthInsights(for: detail)
        } catch {
            healthMetricDetail = nil
            electrocardiograms = []
            healthInsights = []
            healthMetricDetailStatus = .failed
        }
    }

    func requestHealthInsights() async {
        guard let healthMetricDetail else { return }
        await loadHealthInsights(for: healthMetricDetail)
    }

    func loadElectrocardiogramWaveform(recordID: UUID) async {
        selectedElectrocardiogramID = recordID
        electrocardiogramWaveform = nil
        electrocardiogramWaveformMessage = nil
        electrocardiogramWaveformLoading = true
        defer { electrocardiogramWaveformLoading = false }
        do {
            electrocardiogramWaveform = try await healthProvider.electrocardiogramWaveform(for: recordID)
            if electrocardiogramWaveform == nil {
                electrocardiogramWaveformMessage = "这条记录没有可读取的导联 I 波形。请确认 Apple 健康已授权 ECG 读取，且该设备记录支持波形访问。"
            }
        } catch {
            electrocardiogramWaveform = nil
            electrocardiogramWaveformMessage = "无法读取这条心电图波形；请在 Apple 健康中确认该记录可用。"
            alertMessage = electrocardiogramWaveformMessage
        }
    }

    var personalHealthStatistics: PersonalHealthStatistics {
        PersonalHealthStatistics.make(
            records: personalHealthRecords,
            calendar: personalHealthCalendar,
            now: dateProvider.now
        )
    }

    func personalHealthTrendPoints(for category: PersonalHealthCategory) -> [PersonalHealthTrendPoint] {
        PersonalHealthTrendPoint.make(
            category: category,
            records: personalHealthRecords,
            calendar: personalHealthCalendar,
            now: dateProvider.now
        )
    }

    func savePersonalHealthRecord(
        category: PersonalHealthCategory,
        title: String,
        detail: String,
        primaryValue: Double?,
        secondaryValue: Double?,
        tertiaryValue: Double?,
        isCompleted: Bool
    ) async -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty, normalizedTitle.count <= 80,
              detail.count <= 500,
              [primaryValue, secondaryValue, tertiaryValue].allSatisfy({ ($0 ?? 0) >= 0 }) else {
            alertMessage = "请填写有效名称，并检查数值和备注长度。"
            return false
        }
        let record = PersonalHealthRecord(
            id: uuidProvider.make(),
            category: category,
            occurredAt: dateProvider.now,
            title: normalizedTitle,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryValue: primaryValue,
            secondaryValue: secondaryValue,
            tertiaryValue: tertiaryValue,
            isCompleted: isCompleted
        )
        do {
            try await personalHealthRecordProvider?.savePersonalHealthRecord(record)
            personalHealthRecords.insert(record, at: 0)
            return true
        } catch {
            alertMessage = "健康管理记录保存失败，请重试。"
            return false
        }
    }

    func setPersonalHealthRecordCompletion(id: UUID, isCompleted: Bool) async {
        guard let index = personalHealthRecords.firstIndex(where: { $0.id == id }) else { return }
        let previous = personalHealthRecords[index]
        let updated = PersonalHealthRecord(
            id: previous.id,
            category: previous.category,
            occurredAt: previous.occurredAt,
            title: previous.title,
            detail: previous.detail,
            primaryValue: previous.primaryValue,
            secondaryValue: previous.secondaryValue,
            tertiaryValue: previous.tertiaryValue,
            isCompleted: isCompleted
        )
        personalHealthRecords[index] = updated
        do {
            try await personalHealthRecordProvider?.savePersonalHealthRecord(updated)
        } catch {
            personalHealthRecords[index] = previous
            alertMessage = "用药状态保存失败，请重试。"
        }
    }

    func deletePersonalHealthRecord(id: UUID) async {
        guard let index = personalHealthRecords.firstIndex(where: { $0.id == id }) else { return }
        let record = personalHealthRecords.remove(at: index)
        do {
            try await personalHealthRecordProvider?.deletePersonalHealthRecord(id: id)
        } catch {
            personalHealthRecords.insert(record, at: index)
            alertMessage = "健康管理记录删除失败，请重试。"
        }
    }

    private func loadHealthInsights(for detail: HealthMetricDetail) async {
        let request = HealthInsightRequest(
            metric: detail.metric,
            currentValue: detail.currentValue,
            averageValue: detail.average,
            unit: detail.unit,
            period: detail.trend.period,
            generatedAt: dateProvider.now
        )
        healthInsightAccess = await healthInsightProvider.access(for: detail.metric)
        do {
            switch healthInsightAccess {
            case .localOnly:
                healthInsights = try await localHealthInsightProvider.analyze(request)
            case .upgradeRequired:
                healthInsights = []
            case .remoteAvailable:
                healthInsights = try await healthInsightProvider.analyze(request)
            }
        } catch {
            healthInsights = (try? await localHealthInsightProvider.analyze(request)) ?? []
        }
    }

    private var personalHealthCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        return calendar
    }

    func loadMoreExercises() async {
        guard canLoadMoreExercises, !isLoadingMoreExercises else { return }
        isLoadingMoreExercises = true
        defer { isLoadingMoreExercises = false }
        do {
            let nextPage = exercisePage + 1
            let page = try await exerciseCatalogProvider.exercises(
                query: exerciseQuery,
                page: nextPage,
                pageSize: 50
            )
            let knownIDs = Set(exercises.map(\.id))
            exercises.append(contentsOf: page.exercises.filter { !knownIDs.contains($0.id) })
            exercisePage = nextPage
            canLoadMoreExercises = page.hasMore
        } catch let error as LocalizedError {
            exerciseCatalogMessage = error.errorDescription ?? "更多动作加载失败。"
        } catch {
            exerciseCatalogMessage = "更多动作加载失败。"
        }
    }

    func connectHealth() async {
        do {
            try await healthProvider.requestAuthorization()
            await loadHealthData()
        } catch {
            healthStatus = healthProvider.isAvailable ? .failed : .unavailable
            alertMessage = healthProvider.isAvailable
                ? "Apple 健康授权未完成，请在系统设置中检查后重试。"
                : "此设备不支持 Apple 健康。"
        }
    }

    func refreshHealthData() async {
        await loadHealthData()
    }

    func loadTrend(metric: HealthTrendMetric, period: HealthTrendPeriod) async {
        guard healthProvider.isAvailable else {
            healthTrend = .empty(metric: metric, period: period)
            if metric == .steps, period == .week { weeklyStepTrend = healthTrend }
            healthTrendStatus = .unavailable
            return
        }
        healthTrendStatus = .notLoaded
        do {
            healthTrend = try await healthProvider.trend(metric: metric, period: period)
            if metric == .steps, period == .week { weeklyStepTrend = healthTrend }
            healthTrendStatus = healthTrend.availablePoints.isEmpty ? .noData : .available
        } catch {
            healthTrend = .empty(metric: metric, period: period)
            if metric == .steps, period == .week { weeklyStepTrend = healthTrend }
            healthTrendStatus = .failed
        }
        updateDerivedData()
    }

    func join(challengeID: UUID) async {
        await setChallenge(challengeID: challengeID, isJoined: true)
    }

    func leave(challengeID: UUID) async {
        await setChallenge(challengeID: challengeID, isJoined: false)
    }

    private func setChallenge(challengeID: UUID, isJoined: Bool) async {
        guard let index = challenges.firstIndex(where: { $0.id == challengeID }) else { return }
        let previousValue = challenges[index].isJoined
        challenges[index].isJoined = isJoined
        do {
            try await persistenceController?.saveChallenge(id: challengeID, isJoined: isJoined)
        } catch {
            challenges[index].isJoined = previousValue
            alertMessage = "挑战状态保存失败，请重试。"
        }
    }

    func toggleFavorite(articleID: UUID) async {
        guard let index = articles.firstIndex(where: { $0.id == articleID }) else { return }
        articles[index].isFavorite.toggle()
        do {
            try await persistenceController?.saveArticle(
                id: articleID,
                isFavorite: articles[index].isFavorite
            )
        } catch {
            articles[index].isFavorite.toggle()
            alertMessage = "收藏状态保存失败，请重试。"
        }
    }

    func setHidesSensitiveMetrics(_ value: Bool) async {
        let previousValue = hidesSensitiveMetrics
        hidesSensitiveMetrics = value
        do {
            try await persistenceController?.savePreference(
                key: PreferenceKey.hidesSensitiveMetrics,
                value: value
            )
        } catch {
            hidesSensitiveMetrics = previousValue
            alertMessage = "隐私偏好保存失败，请重试。"
        }
    }

    func setAppearance(_ value: AppAppearance) async {
        let previous = appearance
        appearance = value
        do {
            try await persistenceController?.saveStringPreference(
                key: PreferenceKey.appearance,
                value: value.rawValue
            )
        } catch {
            appearance = previous
            alertMessage = "外观偏好保存失败，请重试。"
        }
    }

    func setAppLanguage(_ value: AppLanguage) async {
        let previous = appLanguage
        appLanguage = value
        do {
            try await persistenceController?.saveStringPreference(
                key: PreferenceKey.language,
                value: value.rawValue
            )
            await remoteFeatures.refreshPublic(locale: contentLocale)
            if accountSession != nil {
                await remoteFeatures.refreshPrivate(isAuthenticated: true, locale: contentLocale)
            }
        } catch {
            appLanguage = previous
            alertMessage = "语言偏好保存失败，请重试。"
        }
    }

    func saveProfile(
        nickname: String,
        heightCentimeters: Double,
        weightKilograms: Double,
        bodyFatPercentage: Double
    ) async -> Bool {
        do {
            let updatedProfile = try ProfileInputValidator().validate(
                nickname: nickname,
                heightCentimeters: heightCentimeters,
                weightKilograms: weightKilograms,
                bodyFatPercentage: bodyFatPercentage
            )
            if accountSession != nil {
                guard let remoteProfileProvider else {
                    alertMessage = "当前构建未配置个人资料服务。"
                    return false
                }
                if remoteProfileVersion == nil {
                    let snapshot = try await remoteProfileProvider.currentProfile()
                    remoteProfileVersion = snapshot.version
                }
                guard let version = remoteProfileVersion else {
                    alertMessage = "无法确认服务端资料版本，请刷新后重试。"
                    return false
                }
                let snapshot = try await remoteProfileProvider.updateProfile(
                    updatedProfile,
                    baseVersion: version,
                    operationID: uuidProvider.make()
                )
                remoteProfileVersion = snapshot.version
            }
            try await persistenceController?.save(profile: updatedProfile)
            profile = updatedProfile
            return true
        } catch let error as LocalizedError {
            alertMessage = error.errorDescription ?? "健康指标保存失败。"
            return false
        } catch {
            alertMessage = "健康指标保存失败，请重试。"
            return false
        }
    }

    func signIn(kind: AccountIdentifierKind, identifier: String, password: String) async -> Bool {
        accountOperationInProgress = true
        defer { accountOperationInProgress = false }
        do {
            accountSession = try await authenticationProvider.signIn(
                kind: kind,
                identifier: identifier,
                password: password
            )
            await loadRemoteAccountData()
            alertMessage = "已连接真实服务端账号。"
            return true
        } catch let error as LocalizedError {
            alertMessage = error.errorDescription ?? "登录失败，请重试。"
            return false
        } catch {
            alertMessage = "登录失败，请重试。"
            return false
        }
    }

    func signInSocial(provider: SocialProvider) async -> Bool {
        guard !accountOperationInProgress else { return false }
        guard let socialIdentityProvider else {
            alertMessage = NSLocalizedString("社交登录服务尚未配置。", comment: "Social login unavailable")
            return false
        }
        accountOperationInProgress = true
        defer { accountOperationInProgress = false }
        do {
            let deviceID = try installationIdentity.installationID()
            let newSession: AccountSession
            switch provider {
            case .apple:
                let authorization = try await appleAuthorizationProvider.authorization(deviceID: deviceID)
                newSession = try await socialIdentityProvider.signIn(
                    provider: .apple,
                    authorization: authorization
                )
            case .wechat:
                let authorization = try await wechatAuthorizationProvider.authorization(deviceID: deviceID)
                newSession = try await socialIdentityProvider.signIn(
                    provider: .wechat,
                    authorization: authorization
                )
            case .google:
                guard let googleOAuthAdapter else { throw GoogleOAuthError.notConfigured }
                let completion = try await googleOAuthAdapter.authorize(deviceID: deviceID)
                newSession = try await socialIdentityProvider.completeGoogleSignIn(completion)
            }
            remoteFeatures.clearPrivate()
            accountSession = newSession
            await loadRemoteAccountData()
            alertMessage = NSLocalizedString("已连接真实服务端账号。", comment: "Social sign-in success")
            return true
        } catch {
            alertMessage = socialActionMessage(for: error)
            return false
        }
    }

    func linkSocial(provider: SocialProvider) async -> Bool {
        guard accountSession != nil else {
            alertMessage = NSLocalizedString("请先登录后端账号。", comment: "Binding requires sign-in")
            return false
        }
        guard !accountOperationInProgress else { return false }
        guard let socialIdentityProvider else {
            alertMessage = NSLocalizedString("社交登录服务尚未配置。", comment: "Social binding unavailable")
            return false
        }
        accountOperationInProgress = true
        defer { accountOperationInProgress = false }
        do {
            let attempt: SocialLinkAttempt
            if let pending = pendingSocialLinks[provider] {
                attempt = pending
            } else {
                let deviceID = try installationIdentity.installationID()
                let operationID = uuidProvider.make()
                switch provider {
                case .apple:
                    let authorization = try await appleAuthorizationProvider.authorization(deviceID: deviceID)
                    attempt = .provider(operationID: operationID, authorization: authorization)
                case .wechat:
                    let authorization = try await wechatAuthorizationProvider.authorization(deviceID: deviceID)
                    attempt = .provider(operationID: operationID, authorization: authorization)
                case .google:
                    guard let googleOAuthAdapter else { throw GoogleOAuthError.notConfigured }
                    let completion = try await googleOAuthAdapter.authorize(deviceID: deviceID)
                    attempt = .google(operationID: operationID, completion: completion)
                }
                pendingSocialLinks[provider] = attempt
            }
            switch attempt {
            case let .provider(operationID, authorization):
                _ = try await socialIdentityProvider.link(
                    provider: provider,
                    authorization: authorization,
                    operationID: operationID
                )
            case let .google(operationID, completion):
                _ = try await socialIdentityProvider.linkGoogle(completion, operationID: operationID)
            }
            pendingSocialLinks.removeValue(forKey: provider)
            await remoteFeatures.refreshIdentities()
            alertMessage = NSLocalizedString("账号绑定成功。", comment: "Social binding success")
            return true
        } catch {
            if !shouldRetainSocialAttempt(after: error) {
                pendingSocialLinks.removeValue(forKey: provider)
            }
            alertMessage = socialActionMessage(for: error)
            return false
        }
    }

    func unlinkSocial(provider: SocialProvider) async -> Bool {
        guard accountSession != nil else {
            alertMessage = NSLocalizedString("请先登录后端账号。", comment: "Unlink requires sign-in")
            return false
        }
        guard !accountOperationInProgress else { return false }
        guard let socialIdentityProvider else {
            alertMessage = NSLocalizedString("社交登录服务尚未配置。", comment: "Social unlink unavailable")
            return false
        }
        accountOperationInProgress = true
        defer { accountOperationInProgress = false }
        let operationID = pendingSocialUnlinks[provider] ?? uuidProvider.make()
        pendingSocialUnlinks[provider] = operationID
        do {
            try await socialIdentityProvider.unlink(provider: provider, operationID: operationID)
            pendingSocialUnlinks.removeValue(forKey: provider)
            await remoteFeatures.refreshIdentities()
            alertMessage = NSLocalizedString("账号已解绑。", comment: "Social unlink success")
            return true
        } catch {
            if !shouldRetainSocialAttempt(after: error) {
                pendingSocialUnlinks.removeValue(forKey: provider)
            }
            alertMessage = socialActionMessage(for: error)
            return false
        }
    }

    func register(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String,
        verificationProof: String
    ) async -> Bool {
        accountOperationInProgress = true
        defer { accountOperationInProgress = false }
        do {
            try await authenticationProvider.register(
                kind: kind,
                identifier: identifier,
                password: password,
                verificationProof: verificationProof
            )
            alertMessage = "注册成功，请使用新账号登录。"
            return true
        } catch let error as LocalizedError {
            alertMessage = error.errorDescription ?? "注册失败，请重试。"
            return false
        } catch {
            alertMessage = "注册失败，请重试。"
            return false
        }
    }

    func signOut(allSessions: Bool = false) async {
        await authenticationProvider.signOut(allSessions: allSessions)
        accountSession = nil
        remoteProfileVersion = nil
        remoteWorkouts = []
        remoteWorkoutMessage = nil
        pendingSocialLinks = [:]
        pendingSocialUnlinks = [:]
        remoteFeatures.clearPrivate()
        mergeWorkouts()
    }

    func clearRebuildableCache() async -> Bool {
        do {
            try await persistenceController?.clearRebuildableCache()
            alertMessage = "可重建缓存已清理，运动记录和个人资料均已保留。"
            return true
        } catch {
            alertMessage = "缓存清理失败，请重试。"
            return false
        }
    }

    func prepare(_ type: WorkoutType) {
        switch session.state {
        case .completed, .failed:
            _ = session.send(.reset)
        default:
            break
        }
        workoutDistance = nil
        _ = session.send(.prepare(type))
    }

    func startSession(type: WorkoutType) -> Bool {
        guard session.send(.start(dateProvider.now)) else { return false }
        guard type.usesOutdoorLocation else { return true }
        if locationProvider.authorizationStatus == .notDetermined {
            locationProvider.requestWhenInUseAuthorization()
        }
        locationProvider.start()
        return true
    }

    func pauseSession(elapsed: TimeInterval) {
        guard session.send(.pause(elapsed)) else { return }
        locationProvider.pause()
        refreshWorkoutLocation()
    }

    func resumeSession() -> Bool {
        guard session.send(.resume(dateProvider.now)) else { return false }
        locationProvider.resume()
        return true
    }

    func refreshWorkoutLocation() {
        workoutDistance = locationProvider.snapshot().distance
    }

    func pauseLocationUpdates() {
        locationProvider.pause()
    }

    func abandonSession() {
        _ = locationProvider.stop()
        workoutDistance = nil
        _ = session.send(.cancel)
    }

    func saveManual(type: WorkoutType, durationMinutes: Int, distanceKilometers: Double?) async -> Bool {
        guard durationMinutes > 0 else {
            alertMessage = "请输入有效的运动时长。"
            return false
        }
        let record = WorkoutRecord(
            id: uuidProvider.make(),
            type: type,
            startedAt: dateProvider.now,
            duration: TimeInterval(durationMinutes * 60),
            distance: distanceKilometers.map { Measurement(value: $0, unit: .kilometers) },
            energy: nil,
            route: []
        )
        do {
            try await workoutRepository.save(record, operationID: uuidProvider.make())
            localWorkouts = try await workoutRepository.workouts()
            mergeWorkouts()
            updateDerivedData()
            await uploadWorkoutIfPossible(record, source: .manual)
            return true
        } catch {
            alertMessage = "运动记录保存失败，请重试。"
            return false
        }
    }

    func completeSession(type: WorkoutType, duration: TimeInterval) async -> Bool {
        guard duration > 0, session.send(.finish) else { return false }
        let locationSummary = type.usesOutdoorLocation ? locationProvider.stop() : .empty
        workoutDistance = locationSummary.distance
        let id = uuidProvider.make()
        let record = WorkoutRecord(
            id: id,
            type: type,
            startedAt: dateProvider.now.addingTimeInterval(-duration),
            duration: duration,
            distance: locationSummary.distance,
            energy: nil,
            route: locationSummary.route
        )
        do {
            try await workoutRepository.save(record, operationID: uuidProvider.make())
            localWorkouts = try await workoutRepository.workouts()
            mergeWorkouts()
            updateDerivedData()
            await uploadWorkoutIfPossible(record, source: .moveFitRecorded)
            _ = session.send(.saved(id))
            return true
        } catch {
            _ = session.send(.fail("运动记录保存失败，请重试。"))
            alertMessage = "运动记录保存失败，请重试。"
            return false
        }
    }

    private func loadHealthData() async {
        guard healthProvider.isAvailable else {
            health = .empty
            healthStatus = .unavailable
            healthTrend = .empty(metric: .steps, period: .week)
            weeklyStepTrend = .empty(metric: .steps, period: .week)
            healthTrendStatus = .unavailable
            sleepSummary = nil
            sleepStatus = .unavailable
            updateDerivedData()
            return
        }
        do {
            if let summary = try await healthProvider.dailySummary() {
                health = summary
                healthStatus = .available
            } else {
                health = .empty
                healthStatus = .noData
            }
        } catch {
            health = .empty
            healthStatus = .failed
        }
        await loadTrend(metric: .steps, period: .week)
        await loadSleepData()
        await loadHealthWorkouts()
        updateDerivedData()
    }

    private func loadSleepData() async {
        sleepStatus = .notLoaded
        do {
            sleepSummary = try await healthProvider.sleepSummary()
            sleepStatus = sleepSummary == nil ? .noData : .available
        } catch {
            sleepSummary = nil
            sleepStatus = .failed
        }
    }

    private func loadHealthWorkouts() async {
        do {
            healthWorkouts = try await healthProvider.healthWorkouts()
        } catch {
            healthWorkouts = []
        }
        mergeWorkouts()
    }

    private func mergeWorkouts() {
        workouts = WorkoutMerger().merge(local: localWorkouts, health: healthWorkouts, remote: remoteWorkouts)
    }

    func refreshRemoteData() async {
        await loadBackendConfiguration()
        if accountSession != nil { await loadRemoteAccountData() }
        await loadExercises(query: ExerciseCatalogQuery())
    }

    private func loadBackendConfiguration() async {
        guard let clientConfigurationProvider else { return }
        do {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            let configuration = try await clientConfigurationProvider.configuration(appVersion: version)
            backendConnectionStatus = .connected(revision: configuration.revision)
        } catch let error as LocalizedError {
            backendConnectionStatus = .unavailable(message: error.errorDescription ?? "主服务不可用。")
        } catch {
            backendConnectionStatus = .unavailable(message: "主服务不可用。")
        }
    }

    private func loadRemoteAccountData() async {
        await loadRemoteProfile()
        await loadRemoteWorkouts()
        await remoteFeatures.refreshPrivate(isAuthenticated: true, locale: contentLocale)
    }

    var contentLocale: String {
        if appLanguage == .simplifiedChinese || Locale.current.identifier.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }

    private func shouldRetainSocialAttempt(after error: Error) -> Bool {
        guard let remote = error as? RemoteServiceError else { return false }
        switch remote {
        case .networkUnavailable:
            return true
        case let .server(_, code, _):
            guard let code else { return false }
            return ["social_provider_temporary_failure", "social_idempotency_in_progress"].contains(code)
        default:
            return false
        }
    }

    private func socialActionMessage(for error: Error) -> String {
        if let authorization = error as? SocialAuthorizationError {
            switch authorization {
            case .cancelled:
                return NSLocalizedString("已取消授权，当前账号未改变。", comment: "Authorization cancelled")
            case .providerNotConfigured:
                return NSLocalizedString("微信授权尚未配置 SDK 和 Universal Link。", comment: "WeChat unavailable")
            case .authorizationFailed, .unavailable:
                return NSLocalizedString("无法完成第三方授权，请稍后重试。", comment: "Provider failure")
            }
        }
        if let google = error as? GoogleOAuthError {
            switch google {
            case .cancelled:
                return NSLocalizedString("已取消授权，当前账号未改变。", comment: "Google cancelled")
            case .notConfigured:
                return NSLocalizedString("Google 回调地址尚未配置。", comment: "Google redirect unavailable")
            case .invalidCallback, .stateMismatch, .expiredHandoff:
                return NSLocalizedString("Google 授权已失效，请重新开始。", comment: "Google authorization invalid")
            case .unavailable:
                return NSLocalizedString("无法打开 Google 授权页面。", comment: "Google browser unavailable")
            }
        }
        if let remote = error as? RemoteServiceError {
            switch remote {
            case .networkUnavailable:
                return NSLocalizedString("服务暂时不可用，请稍后重试。", comment: "Network unavailable")
            case .authenticationRequired:
                return NSLocalizedString("登录已失效，请重新登录。", comment: "Auth required")
            case let .server(_, code, _):
                switch code {
                case "social_identity_conflict":
                    return NSLocalizedString("该身份已绑定其他账号。", comment: "Social identity conflict")
                case "last_login_identity_required", "last_login_method_required":
                    return NSLocalizedString("不能解绑最后一种登录方式。", comment: "Last login method")
                case "social_provider_unavailable", "google_provider_unavailable":
                    return NSLocalizedString("服务端尚未配置该授权方式。", comment: "Provider not configured")
                case "social_idempotency_in_progress":
                    return NSLocalizedString("请求仍在处理，请稍后重试。", comment: "Idempotency in progress")
                default:
                    return NSLocalizedString("授权失败，请重新尝试。", comment: "Social authorization failed")
                }
            case .invalidRequest, .invalidResponse:
                return NSLocalizedString("授权失败，请重新尝试。", comment: "Social authorization failed")
            }
        }
        return NSLocalizedString("授权失败，请重新尝试。", comment: "Social authorization failed")
    }

    private func loadRemoteProfile() async {
        guard let remoteProfileProvider else { return }
        do {
            let snapshot = try await remoteProfileProvider.currentProfile()
            remoteProfileVersion = snapshot.version
            let local = profile
            if let nickname = snapshot.nickname ?? local?.nickname,
               let height = snapshot.height ?? local?.height,
               let weight = snapshot.weight ?? local?.weight,
               let bodyFat = snapshot.bodyFatPercentage ?? local?.bodyFatPercentage {
                let mergedProfile = UserProfile(
                    nickname: nickname,
                    height: height,
                    weight: weight,
                    bodyFatPercentage: bodyFat
                )
                profile = mergedProfile
                try? await persistenceController?.save(profile: mergedProfile)
            }
        } catch let error as LocalizedError {
            alertMessage = error.errorDescription ?? "服务端个人资料加载失败。"
        } catch {
            alertMessage = "服务端个人资料加载失败。"
        }
    }

    private func loadRemoteWorkouts() async {
        guard let remoteWorkoutProvider else { return }
        do {
            remoteWorkouts = try await remoteWorkoutProvider.workouts()
            remoteWorkoutMessage = "已合并服务端全部运动记录。"
        } catch let error as LocalizedError {
            remoteWorkoutMessage = error.errorDescription ?? "服务端运动历史未加载。"
        } catch {
            remoteWorkoutMessage = "服务端运动历史未加载。"
        }
        mergeWorkouts()
        updateDerivedData()
    }

    private func uploadWorkoutIfPossible(_ workout: WorkoutRecord, source: RemoteWorkoutSource) async {
        guard accountSession != nil, let remoteWorkoutProvider else { return }
        do {
            try await remoteWorkoutProvider.upload(workout, source: source, operationID: workout.id)
            remoteWorkoutMessage = "最近运动已同步到服务端。"
            await loadRemoteWorkouts()
        } catch let error as BackendError where error == .unsupportedWorkoutType {
            remoteWorkoutMessage = error.localizedDescription
            alertMessage = error.localizedDescription
        } catch let error as LocalizedError {
            remoteWorkoutMessage = "本地已保存；服务端同步失败：\(error.errorDescription ?? "未知错误")"
            alertMessage = remoteWorkoutMessage
        } catch {
            remoteWorkoutMessage = "本地已保存；服务端同步失败。"
            alertMessage = remoteWorkoutMessage
        }
    }

    private func updateDerivedData() {
        challenges.indices.forEach { index in
            challenges[index].progress = challengeProgress(for: challenges[index].metric)
        }
    }

    private func challengeProgress(for metric: ChallengeMetric) -> Double? {
        let calendar = Calendar.current
        let workoutDays: (Set<WorkoutType>) -> Double = { types in
            Double(Set(
                self.workouts
                    .filter { types.contains($0.type) }
                    .map { calendar.startOfDay(for: $0.startedAt) }
            ).count)
        }
        switch metric {
        case .steps:
            if !weeklyStepTrend.availablePoints.isEmpty { return weeklyStepTrend.total }
            return health.steps.map(Double.init)
        case .longestRunningDistance:
            return workouts
                .filter { $0.type == .running }
                .compactMap { $0.distance?.converted(to: .kilometers).value }
                .max()
        case .totalCyclingDistance:
            let total = workouts
                .filter { $0.type == .cycling }
                .compactMap { $0.distance?.converted(to: .kilometers).value }
                .reduce(0, +)
            return total > 0 ? total : nil
        case .strengthDays:
            return workoutDays([.strength])
        case .hiitDays:
            return workoutDays([.hiit])
        case .recoveryDays:
            return workoutDays([.walking, .yoga, .pilates])
        }
    }

    private static let defaultArticles = [
        WellnessArticle(
            id: StableID.recoveryStretching,
            title: "训练后的轻松拉伸",
            category: "运动",
            summary: "用 8 分钟帮助身体从训练状态平稳恢复。",
            isFavorite: false
        ),
        WellnessArticle(
            id: StableID.stableSchedule,
            title: "稳定作息的三个小动作",
            category: "作息",
            summary: "从固定起床时间、晨间光照和睡前放松开始。",
            isFavorite: false
        )
    ]
}

private enum PreferenceKey {
    static let hidesSensitiveMetrics = "hidesSensitiveMetrics"
    static let appearance = "appearance"
    static let language = "language"
}

private enum StableID {
    static let springSteps = make(1)
    static let weekendFiveK = make(2)
    static let coreFourteenDays = make(3)
    static let recoveryStretching = make(4)
    static let stableSchedule = make(5)
    static let firstFiveK = make(6)
    static let sevenActiveDays = make(7)
    static let hundredKilometerCycling = make(8)

    private static func make(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

private extension WorkoutType {
    var usesOutdoorLocation: Bool {
        self == .running || self == .walking || self == .cycling
    }
}
