import XCTest
@testable import MoveFit

@MainActor
final class RemoteFeatureViewModelTests: XCTestCase {
    func testMissingRemoteProvidersKeepExplicitLocalFallback() async {
        let viewModel = RemoteFeatureViewModel()

        await viewModel.refreshPublic(locale: "zh-Hans")

        XCTAssertEqual(viewModel.challengeStatus, .localFallback)
        XCTAssertEqual(viewModel.articleStatus, .localFallback)
        XCTAssertEqual(viewModel.helpStatus, .localFallback)
        XCTAssertTrue(viewModel.challenges.isEmpty)
    }

    func testUnauthenticatedRefreshClearsPrivateStateWithoutNetwork() async {
        let viewModel = RemoteFeatureViewModel()

        await viewModel.refreshPrivate(isAuthenticated: false, locale: "zh-Hans")

        XCTAssertEqual(viewModel.identityStatus, .signInRequired)
        XCTAssertEqual(viewModel.participationStatus, .signInRequired)
        XCTAssertEqual(viewModel.favoriteStatus, .signInRequired)
        XCTAssertEqual(viewModel.ticketStatus, .signInRequired)
    }

    func testRemoteChallengeFailureDoesNotMasqueradeAsServerData() async {
        let provider = FailingChallengeProvider()
        let viewModel = RemoteFeatureViewModel(challengeProvider: provider)

        await viewModel.refreshPublic(locale: "zh-Hans")

        XCTAssertEqual(viewModel.challengeStatus, .localFallback)
        XCTAssertTrue(viewModel.challenges.isEmpty)
        XCTAssertEqual(provider.catalogCalls, 1)
    }

    func testRemoteChallengePaginationAppendsOnlyTheNextPage() async {
        let provider = PagedChallengeProvider()
        let viewModel = RemoteFeatureViewModel(challengeProvider: provider)

        await viewModel.refreshChallenges(locale: "zh-Hans")
        XCTAssertEqual(viewModel.challenges.count, 1)
        XCTAssertTrue(viewModel.canLoadMoreChallenges)

        await viewModel.loadMoreChallenges(locale: "zh-Hans")
        XCTAssertEqual(viewModel.challenges.count, 2)
        XCTAssertFalse(viewModel.canLoadMoreChallenges)
        XCTAssertEqual(provider.requestedCursors, [nil, "next"])
    }

    func testFailedChallengeWriteKeepsServerParticipationEmpty() async {
        let viewModel = RemoteFeatureViewModel(challengeProvider: FailingChallengeProvider())

        let succeeded = await viewModel.join(
            challengeID: UUID(), locale: "zh-Hans", operationID: UUID()
        )

        XCTAssertFalse(succeeded)
        XCTAssertTrue(viewModel.participations.isEmpty)
        XCTAssertEqual(viewModel.lastWriteError, .networkUnavailable)
    }

    func testParticipationRefreshReadsAllPagesBeforeReportingRemoteStatus() async {
        let provider = PagedChallengeProvider()
        let viewModel = RemoteFeatureViewModel(challengeProvider: provider)

        await viewModel.refreshParticipations()

        XCTAssertEqual(viewModel.participationStatus, .remote)
        XCTAssertEqual(viewModel.participations.count, 2)
        XCTAssertEqual(provider.participationCursors, [nil, "next-participation"])
    }

    func testFavoriteRefreshReadsAllPagesBeforeReportingRemoteStatus() async {
        let provider = PagedContentProvider()
        let viewModel = RemoteFeatureViewModel(contentProvider: provider)

        await viewModel.refreshFavorites(locale: "zh-Hans")

        XCTAssertEqual(viewModel.favoriteStatus, .remote)
        XCTAssertEqual(viewModel.favorites.count, 2)
        XCTAssertEqual(provider.favoriteCursors, [nil, "next-favorite"])
    }
}

private final class PagedContentProvider: ContentProviding {
    private(set) var favoriteCursors: [String?] = []

    func articles(locale: String, cursor: String?) async throws -> RemotePage<RemoteArticle> {
        throw RemoteServiceError.invalidRequest
    }

    func article(id: UUID, locale: String) async throws -> RemoteArticle {
        throw RemoteServiceError.invalidRequest
    }

    func favorites(
        locale: String, cursor: String?
    ) async throws -> RemotePage<RemoteFavoriteArticleSummary> {
        favoriteCursors.append(cursor)
        let favorite = RemoteFavoriteArticleSummary(
            id: UUID(), title: "Test", summary: "Test", category: "general",
            locale: locale, revision: 1, favoriteVersion: 1, favoriteUpdatedAt: Date()
        )
        return RemotePage(
            items: [favorite], nextCursor: cursor == nil ? "next-favorite" : nil,
            hasMore: cursor == nil
        )
    }

    func setFavorite(
        articleID: UUID, isFavorite: Bool, operationID: UUID
    ) async throws -> RemoteArticleFavorite? {
        throw RemoteServiceError.invalidRequest
    }
}

private final class PagedChallengeProvider: ChallengeRemoteProviding {
    private(set) var requestedCursors: [String?] = []
    private(set) var participationCursors: [String?] = []

    func challenges(locale: String, cursor: String?) async throws -> RemotePage<RemoteChallenge> {
        requestedCursors.append(cursor)
        let challenge = RemoteChallenge(
            id: UUID(), title: "Test", summary: "Test", metric: "distance", goalValue: 5,
            goalUnit: "km", startsAt: Date(), endsAt: Date(), enrollmentOpensAt: Date(),
            enrollmentClosesAt: Date(), exitClosesAt: nil, eligibleWorkoutTypes: [],
            eligibleWorkoutSources: [], ruleVersion: 1
        )
        return RemotePage(
            items: [challenge],
            nextCursor: cursor == nil ? "next" : nil,
            hasMore: cursor == nil
        )
    }

    func challenge(id: UUID, locale: String) async throws -> RemoteChallenge {
        throw RemoteServiceError.invalidRequest
    }
    func participations(cursor: String?) async throws -> RemotePage<RemoteChallengeParticipation> {
        participationCursors.append(cursor)
        let participation = RemoteChallengeParticipation(
            id: UUID(), challengeID: UUID(), status: "active", progressValue: 0,
            goalValue: 5, goalUnit: "km", isComplete: false, calculatedAt: Date()
        )
        return RemotePage(
            items: [participation],
            nextCursor: cursor == nil ? "next-participation" : nil,
            hasMore: cursor == nil
        )
    }
    func join(challengeID: UUID, locale: String, operationID: UUID) async throws -> RemoteChallengeParticipation {
        throw RemoteServiceError.invalidRequest
    }
    func leave(challengeID: UUID, operationID: UUID) async throws {
        throw RemoteServiceError.invalidRequest
    }
    func leaderboard(challengeID: UUID, cursor: String?) async throws -> RemoteLeaderboard {
        throw RemoteServiceError.invalidRequest
    }
}

private final class FailingChallengeProvider: ChallengeRemoteProviding {
    private(set) var catalogCalls = 0

    func challenges(locale: String, cursor: String?) async throws -> RemotePage<RemoteChallenge> {
        catalogCalls += 1
        throw RemoteServiceError.networkUnavailable
    }

    func challenge(id: UUID, locale: String) async throws -> RemoteChallenge {
        throw RemoteServiceError.networkUnavailable
    }

    func participations(cursor: String?) async throws -> RemotePage<RemoteChallengeParticipation> {
        throw RemoteServiceError.networkUnavailable
    }

    func join(
        challengeID: UUID,
        locale: String,
        operationID: UUID
    ) async throws -> RemoteChallengeParticipation {
        throw RemoteServiceError.networkUnavailable
    }

    func leave(challengeID: UUID, operationID: UUID) async throws {
        throw RemoteServiceError.networkUnavailable
    }

    func leaderboard(challengeID: UUID, cursor: String?) async throws -> RemoteLeaderboard {
        throw RemoteServiceError.networkUnavailable
    }
}
