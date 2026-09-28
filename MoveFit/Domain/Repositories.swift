import Foundation
import CoreLocation

protocol WorkoutRepository {
    func workouts() async throws -> [WorkoutRecord]
    func save(_ workout: WorkoutRecord, operationID: UUID) async throws
}

protocol HealthDataProviding {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    func dailySummary() async throws -> HealthSummary?
    func trend(metric: HealthTrendMetric, period: HealthTrendPeriod) async throws -> HealthTrend
    func metricDetail(for metric: HomeHealthMetric) async throws -> HealthMetricDetail?
    func electrocardiogramSummaries() async throws -> [ECGRecordSummary]
    func electrocardiogramWaveform(for recordID: UUID) async throws -> ECGWaveform?
    func sleepSummary() async throws -> SleepSummary?
    func healthWorkouts() async throws -> [WorkoutRecord]
}

extension HealthDataProviding {
    func trend(metric: HealthTrendMetric, period: HealthTrendPeriod) async throws -> HealthTrend {
        .empty(metric: metric, period: period)
    }

    func metricDetail(for metric: HomeHealthMetric) async throws -> HealthMetricDetail? { nil }
    func electrocardiogramSummaries() async throws -> [ECGRecordSummary] { [] }
    func electrocardiogramWaveform(for recordID: UUID) async throws -> ECGWaveform? { nil }
    func sleepSummary() async throws -> SleepSummary? { nil }
    func healthWorkouts() async throws -> [WorkoutRecord] { [] }
}

protocol LocationProviding {
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func start()
    func pause()
    func resume()
    func snapshot() -> WorkoutLocationSummary
    func stop() -> WorkoutLocationSummary
}

protocol CredentialStoring {
    func save(token: String, account: String) throws
    func token(account: String) throws -> String?
    func delete(account: String) throws
}

protocol AuthenticationProviding {
    func restoreSession() async throws -> AccountSession?
    func signIn(kind: AccountIdentifierKind, identifier: String, password: String) async throws -> AccountSession
    func register(
        kind: AccountIdentifierKind,
        identifier: String,
        password: String,
        verificationProof: String
    ) async throws
    func signOut(allSessions: Bool) async
}

protocol RemoteProfileProviding {
    func currentProfile() async throws -> RemoteProfileSnapshot
    func updateProfile(_ profile: UserProfile, baseVersion: Int, operationID: UUID) async throws
        -> RemoteProfileSnapshot
}

protocol RemoteWorkoutProviding {
    func workouts() async throws -> [WorkoutRecord]
    func upload(_ workout: WorkoutRecord, source: RemoteWorkoutSource, operationID: UUID) async throws
}

protocol ClientConfigurationProviding {
    func configuration(appVersion: String) async throws -> BackendClientConfiguration
}

protocol GoogleAuthorizationHandoffProviding {
    func beginGoogleAuthorization(
        redirectURI: URL,
        codeChallenge: String,
        deviceID: String
    ) async throws -> GoogleAuthorizationHandoff
}

protocol SocialIdentityProviding: GoogleAuthorizationHandoffProviding {
    func signIn(provider: SocialProvider, authorization: SocialAuthorization) async throws -> AccountSession
    func completeGoogleSignIn(_ completion: GoogleAuthorizationCompletion) async throws -> AccountSession
    func identities() async throws -> [SocialIdentity]
    func link(
        provider: SocialProvider,
        authorization: SocialAuthorization,
        operationID: UUID
    ) async throws -> SocialIdentity
    func linkGoogle(
        _ completion: GoogleAuthorizationCompletion,
        operationID: UUID
    ) async throws -> SocialIdentity
    func unlink(provider: SocialProvider, operationID: UUID) async throws
}

protocol ChallengeRemoteProviding {
    func challenges(locale: String, cursor: String?) async throws -> RemotePage<RemoteChallenge>
    func challenge(id: UUID, locale: String) async throws -> RemoteChallenge
    func participations(cursor: String?) async throws -> RemotePage<RemoteChallengeParticipation>
    func join(challengeID: UUID, locale: String, operationID: UUID) async throws -> RemoteChallengeParticipation
    func leave(challengeID: UUID, operationID: UUID) async throws
    func leaderboard(challengeID: UUID, cursor: String?) async throws -> RemoteLeaderboard
}

protocol ContentProviding {
    func articles(locale: String, cursor: String?) async throws -> RemotePage<RemoteArticle>
    func article(id: UUID, locale: String) async throws -> RemoteArticle
    func favorites(locale: String, cursor: String?) async throws -> RemotePage<RemoteFavoriteArticleSummary>
    func setFavorite(articleID: UUID, isFavorite: Bool, operationID: UUID) async throws
        -> RemoteArticleFavorite?
}

protocol SupportProviding {
    func helpArticles(locale: String, cursor: String?) async throws -> RemotePage<RemoteHelpArticle>
    func helpArticle(id: UUID, locale: String) async throws -> RemoteHelpArticle
    func tickets(cursor: String?) async throws -> RemotePage<RemoteSupportTicket>
    func ticket(id: UUID) async throws -> RemoteSupportTicketDetail
    func createTicket(
        category: String,
        subject: String,
        message: String,
        operationID: UUID
    ) async throws -> RemoteSupportTicketDetail
    func reply(ticketID: UUID, message: String, operationID: UUID) async throws -> RemoteSupportTicketReply
    func close(ticketID: UUID, operationID: UUID) async throws -> RemoteSupportTicket
}

protocol TrainingCatalogProviding {
    func plans(locale: String) async throws -> TrainingCatalogResult
}

protocol ExerciseCatalogProviding {
    func exercises(query: ExerciseCatalogQuery, page: Int, pageSize: Int) async throws -> ExerciseCatalogPage
}

protocol PersonalHealthRecordProviding {
    func personalHealthRecords() async throws -> [PersonalHealthRecord]
    func savePersonalHealthRecord(_ record: PersonalHealthRecord) async throws
    func deletePersonalHealthRecord(id: UUID) async throws
}

protocol DateProviding { var now: Date { get } }
protocol UUIDProviding { func make() -> UUID }

struct SystemDateProvider: DateProviding { var now: Date { Date() } }
struct SystemUUIDProvider: UUIDProviding { func make() -> UUID { UUID() } }
