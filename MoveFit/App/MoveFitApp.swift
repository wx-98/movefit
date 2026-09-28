import SwiftUI

@main
struct MoveFitApp: App {
    @StateObject private var model: AppModel
    private let registrationViewModelFactory: RegistrationViewModelFactory

    init() {
        let persistenceController = PersistenceController()
        let environment = AppEnvironment.current
        let sessionStore = BackendSessionStore()
        let apiClient = MoveFitAPIClient(
            baseURL: environment.backendBaseURL,
            sessionStore: sessionStore
        )
        let backendRepository = BackendRepository(client: apiClient)
        let remoteFeatures = RemoteFeatureViewModel(
            socialProvider: backendRepository,
            challengeProvider: backendRepository,
            contentProvider: backendRepository,
            supportProvider: backendRepository
        )
        let googleOAuth = GoogleOAuthAdapter(
            handoff: backendRepository,
            browser: SystemGoogleBrowserAuthenticationAdapter(),
            redirectURI: environment.googleRedirectURI
        )
        let exerciseRepository = FallbackExerciseCatalogRepository(
            remote: RemoteExerciseCatalogRepository(baseURL: environment.exerciseBaseURL)
        )
        let aiInsightRepository = RemoteAIHealthInsightRepository(
            client: AIHealthInsightAPIClient(baseURL: environment.aiBaseURL, sessionStore: sessionStore)
        )
        let trainingCatalogProvider = Self.makeTrainingCatalog(client: apiClient)
        _model = StateObject(
            wrappedValue: AppModel(
                workoutRepository: CoreDataWorkoutRepository(persistenceController: persistenceController),
                healthProvider: HealthKitAdapter(),
                locationProvider: LocationAdapter(),
                persistenceController: persistenceController,
                authenticationProvider: backendRepository,
                socialIdentityProvider: backendRepository,
                googleOAuthAdapter: googleOAuth,
                remoteProfileProvider: backendRepository,
                remoteWorkoutProvider: backendRepository,
                clientConfigurationProvider: backendRepository,
                trainingCatalogProvider: trainingCatalogProvider,
                exerciseCatalogProvider: exerciseRepository,
                healthInsightProvider: aiInsightRepository,
                remoteFeatures: remoteFeatures
            )
        )
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-registration") {
            registrationViewModelFactory = .uiTesting(
                authenticationProvider: backendRepository,
                rateLimited: ProcessInfo.processInfo.arguments.contains(
                    "-ui-testing-registration-rate-limit"
                )
            )
        } else {
            registrationViewModelFactory = RegistrationViewModelFactory(
                verificationProvider: backendRepository,
                authenticationProvider: backendRepository
            )
        }
#else
        registrationViewModelFactory = RegistrationViewModelFactory(
            verificationProvider: backendRepository,
            authenticationProvider: backendRepository
        )
#endif
    }

    private static func makeTrainingCatalog(client: MoveFitAPIClient) -> TrainingCatalogProviding {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-training-catalog-empty") {
            return UITestEmptyTrainingCatalog()
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-training-catalog-fallback") {
            return BundledTrainingCatalog()
        }
#endif
        return FallbackTrainingCatalogRepository(remote: RemoteTrainingCatalogRepository(client: client))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(registrationViewModelFactory: registrationViewModelFactory)
                .environmentObject(model)
                .environmentObject(model.remoteFeatures)
                .preferredColorScheme(model.appearance.colorScheme)
                .environment(\.locale, model.appLanguage.locale)
        }
    }
}

#if DEBUG
private struct UITestEmptyTrainingCatalog: TrainingCatalogProviding {
    func plans(locale: String) async throws -> TrainingCatalogResult {
        TrainingCatalogResult(plans: [], source: .remote)
    }
}
#endif

private extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private extension AppLanguage {
    var locale: Locale {
        switch self {
        case .system: return .current
        case .simplifiedChinese: return Locale(identifier: "zh-Hans")
        }
    }
}
