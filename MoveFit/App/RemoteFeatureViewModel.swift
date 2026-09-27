import Foundation

enum RemoteFeatureStatus: Equatable {
    case notLoaded
    case loading
    case remote
    case cached
    case localFallback
    case signInRequired
    case unavailable
}

@MainActor
final class RemoteFeatureViewModel: ObservableObject {
    @Published private(set) var challenges: [RemoteChallenge] = []
    @Published private(set) var articles: [RemoteArticle] = []
    @Published private(set) var helpArticles: [RemoteHelpArticle] = []
    @Published private(set) var identities: [SocialIdentity] = []
    @Published private(set) var participations: [RemoteChallengeParticipation] = []
    @Published private(set) var favorites: [RemoteFavoriteArticleSummary] = []
    @Published private(set) var tickets: [RemoteSupportTicket] = []
    @Published private(set) var challengeStatus = RemoteFeatureStatus.notLoaded
    @Published private(set) var articleStatus = RemoteFeatureStatus.notLoaded
    @Published private(set) var helpStatus = RemoteFeatureStatus.notLoaded
    @Published private(set) var identityStatus = RemoteFeatureStatus.signInRequired
    @Published private(set) var participationStatus = RemoteFeatureStatus.signInRequired
    @Published private(set) var favoriteStatus = RemoteFeatureStatus.signInRequired
    @Published private(set) var ticketStatus = RemoteFeatureStatus.signInRequired
    @Published private(set) var isWriting = false
    @Published private(set) var canLoadMoreChallenges = false
    @Published private(set) var isLoadingMoreChallenges = false
    @Published private(set) var canLoadMoreArticles = false
    @Published private(set) var canLoadMoreHelp = false
    @Published private(set) var canLoadMoreTickets = false
    @Published private(set) var lastWriteError: RemoteServiceError?

    private let socialProvider: SocialIdentityProviding?
    private let challengeProvider: ChallengeRemoteProviding?
    private let contentProvider: ContentProviding?
    private let supportProvider: SupportProviding?
    private var challengeNextCursor: String?
    private var articleNextCursor: String?
    private var helpNextCursor: String?
    private var ticketNextCursor: String?

    init(
        socialProvider: SocialIdentityProviding? = nil,
        challengeProvider: ChallengeRemoteProviding? = nil,
        contentProvider: ContentProviding? = nil,
        supportProvider: SupportProviding? = nil
    ) {
        self.socialProvider = socialProvider
        self.challengeProvider = challengeProvider
        self.contentProvider = contentProvider
        self.supportProvider = supportProvider
    }

    func refreshPublic(locale: String) async {
        await refreshChallenges(locale: locale)
        await refreshArticles(locale: locale)
        await refreshHelp(locale: locale)
    }

    func refreshPrivate(isAuthenticated: Bool, locale: String) async {
        guard isAuthenticated else {
            clearPrivate()
            return
        }
        await refreshIdentities()
        await refreshParticipations()
        await refreshFavorites(locale: locale)
        await refreshTickets()
    }

    func clearPrivate() {
        identities = []
        participations = []
        favorites = []
        tickets = []
        ticketNextCursor = nil
        canLoadMoreTickets = false
        identityStatus = .signInRequired
        participationStatus = .signInRequired
        favoriteStatus = .signInRequired
        ticketStatus = .signInRequired
        lastWriteError = nil
    }

    func refreshChallenges(locale: String) async {
        guard challengeStatus != .loading else { return }
        guard let challengeProvider else {
            challenges = []
            challengeStatus = .localFallback
            challengeNextCursor = nil
            canLoadMoreChallenges = false
            return
        }
        challengeStatus = .loading
        do {
            let page = try await challengeProvider.challenges(locale: locale, cursor: nil)
            challenges = page.items
            challengeNextCursor = page.nextCursor
            canLoadMoreChallenges = page.hasMore && page.nextCursor != nil
            challengeStatus = page.items.isEmpty ? .localFallback : .remote
        } catch {
            challengeStatus = challenges.isEmpty ? .localFallback : .cached
        }
    }

    func loadMoreChallenges(locale: String) async {
        guard let challengeProvider, let cursor = challengeNextCursor,
              canLoadMoreChallenges, !isLoadingMoreChallenges else { return }
        isLoadingMoreChallenges = true
        defer { isLoadingMoreChallenges = false }
        do {
            let page = try await challengeProvider.challenges(locale: locale, cursor: cursor)
            let existingIDs = Set(challenges.map(\.id))
            challenges.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
            challengeNextCursor = page.nextCursor
            canLoadMoreChallenges = page.hasMore && page.nextCursor != nil
            challengeStatus = .remote
        } catch {
            challengeStatus = challenges.isEmpty ? .localFallback : .cached
        }
    }

    func refreshArticles(locale: String) async {
        guard articleStatus != .loading else { return }
        guard let contentProvider else {
            articles = []
            articleStatus = .localFallback
            articleNextCursor = nil
            canLoadMoreArticles = false
            return
        }
        articleStatus = .loading
        do {
            let page = try await contentProvider.articles(locale: locale, cursor: nil)
            articles = page.items
            articleNextCursor = page.nextCursor
            canLoadMoreArticles = page.hasMore && page.nextCursor != nil
            articleStatus = page.items.isEmpty ? .localFallback : .remote
        } catch {
            articleStatus = articles.isEmpty ? .localFallback : .cached
        }
    }

    func loadMoreArticles(locale: String) async {
        guard let contentProvider, let cursor = articleNextCursor, canLoadMoreArticles else { return }
        canLoadMoreArticles = false
        do {
            let page = try await contentProvider.articles(locale: locale, cursor: cursor)
            let existingIDs = Set(articles.map(\.id))
            articles.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
            articleNextCursor = page.nextCursor
            canLoadMoreArticles = page.hasMore && page.nextCursor != nil
            articleStatus = .remote
        } catch {
            canLoadMoreArticles = true
            articleStatus = articles.isEmpty ? .localFallback : .cached
        }
    }

    func refreshHelp(locale: String) async {
        guard helpStatus != .loading else { return }
        guard let supportProvider else {
            helpArticles = []
            helpStatus = .localFallback
            helpNextCursor = nil
            canLoadMoreHelp = false
            return
        }
        helpStatus = .loading
        do {
            let page = try await supportProvider.helpArticles(locale: locale, cursor: nil)
            helpArticles = page.items
            helpNextCursor = page.nextCursor
            canLoadMoreHelp = page.hasMore && page.nextCursor != nil
            helpStatus = page.items.isEmpty ? .localFallback : .remote
        } catch {
            helpStatus = helpArticles.isEmpty ? .localFallback : .cached
        }
    }

    func loadMoreHelp(locale: String) async {
        guard let supportProvider, let cursor = helpNextCursor, canLoadMoreHelp else { return }
        canLoadMoreHelp = false
        do {
            let page = try await supportProvider.helpArticles(locale: locale, cursor: cursor)
            let existingIDs = Set(helpArticles.map(\.id))
            helpArticles.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
            helpNextCursor = page.nextCursor
            canLoadMoreHelp = page.hasMore && page.nextCursor != nil
            helpStatus = .remote
        } catch {
            canLoadMoreHelp = true
            helpStatus = helpArticles.isEmpty ? .localFallback : .cached
        }
    }

    func refreshIdentities() async {
        guard let socialProvider else {
            identityStatus = .unavailable
            return
        }
        identityStatus = .loading
        do {
            identities = try await socialProvider.identities()
            identityStatus = .remote
        } catch {
            identityStatus = identities.isEmpty ? .unavailable : .cached
        }
    }

    func refreshParticipations() async {
        guard let challengeProvider else {
            participationStatus = .unavailable
            return
        }
        participationStatus = .loading
        do {
            participations = try await fetchAllPages { cursor in
                try await challengeProvider.participations(cursor: cursor)
            }
            participationStatus = .remote
        } catch {
            participationStatus = participations.isEmpty ? .unavailable : .cached
        }
    }

    func refreshFavorites(locale: String) async {
        guard let contentProvider else {
            favoriteStatus = .unavailable
            return
        }
        favoriteStatus = .loading
        do {
            favorites = try await fetchAllPages { cursor in
                try await contentProvider.favorites(locale: locale, cursor: cursor)
            }
            favoriteStatus = .remote
        } catch {
            favoriteStatus = favorites.isEmpty ? .unavailable : .cached
        }
    }

    private func fetchAllPages<Item>(
        _ fetch: (String?) async throws -> RemotePage<Item>
    ) async throws -> [Item] {
        var items: [Item] = []
        var cursor: String?
        var visitedCursors: Set<String> = []
        while true {
            let page = try await fetch(cursor)
            items.append(contentsOf: page.items)
            guard page.hasMore else { return items }
            guard let nextCursor = page.nextCursor,
                  visitedCursors.insert(nextCursor).inserted else {
                throw RemoteServiceError.invalidResponse
            }
            cursor = nextCursor
        }
    }

    func refreshTickets() async {
        guard let supportProvider else {
            ticketStatus = .unavailable
            ticketNextCursor = nil
            canLoadMoreTickets = false
            return
        }
        ticketStatus = .loading
        do {
            let page = try await supportProvider.tickets(cursor: nil)
            tickets = page.items
            ticketNextCursor = page.nextCursor
            canLoadMoreTickets = page.hasMore && page.nextCursor != nil
            ticketStatus = .remote
        } catch {
            ticketStatus = tickets.isEmpty ? .unavailable : .cached
        }
    }

    func loadMoreTickets() async {
        guard let supportProvider, let cursor = ticketNextCursor, canLoadMoreTickets else { return }
        canLoadMoreTickets = false
        do {
            let page = try await supportProvider.tickets(cursor: cursor)
            let existingIDs = Set(tickets.map(\.id))
            tickets.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
            ticketNextCursor = page.nextCursor
            canLoadMoreTickets = page.hasMore && page.nextCursor != nil
            ticketStatus = .remote
        } catch {
            canLoadMoreTickets = true
            ticketStatus = tickets.isEmpty ? .unavailable : .cached
        }
    }

    func join(challengeID: UUID, locale: String, operationID: UUID) async -> Bool {
        guard let challengeProvider else {
            lastWriteError = .invalidRequest
            return false
        }
        isWriting = true
        defer { isWriting = false }
        do {
            let joined = try await challengeProvider.join(
                challengeID: challengeID,
                locale: locale,
                operationID: operationID
            )
            participations.removeAll { $0.challengeID == challengeID }
            participations.append(joined)
            participationStatus = .remote
            lastWriteError = nil
            return true
        } catch {
            lastWriteError = RemoteServiceError.map(error)
            return false
        }
    }

    func leave(challengeID: UUID, operationID: UUID) async -> Bool {
        guard let challengeProvider else {
            lastWriteError = .invalidRequest
            return false
        }
        isWriting = true
        defer { isWriting = false }
        do {
            try await challengeProvider.leave(challengeID: challengeID, operationID: operationID)
            participations.removeAll { $0.challengeID == challengeID }
            await refreshParticipations()
            lastWriteError = nil
            return true
        } catch {
            lastWriteError = RemoteServiceError.map(error)
            return false
        }
    }

    func setFavorite(
        articleID: UUID,
        isFavorite: Bool,
        locale: String,
        operationID: UUID
    ) async -> Bool {
        guard let contentProvider else {
            lastWriteError = .invalidRequest
            return false
        }
        isWriting = true
        defer { isWriting = false }
        do {
            _ = try await contentProvider.setFavorite(
                articleID: articleID,
                isFavorite: isFavorite,
                operationID: operationID
            )
            await refreshFavorites(locale: locale)
            lastWriteError = nil
            return true
        } catch {
            lastWriteError = RemoteServiceError.map(error)
            return false
        }
    }

    func createTicket(
        category: String,
        subject: String,
        message: String,
        operationID: UUID
    ) async -> RemoteSupportTicketDetail? {
        guard let supportProvider else {
            lastWriteError = .invalidRequest
            return nil
        }
        isWriting = true
        defer { isWriting = false }
        do {
            let detail = try await supportProvider.createTicket(
                category: category,
                subject: subject,
                message: message,
                operationID: operationID
            )
            tickets.insert(detail.ticket, at: 0)
            ticketStatus = .remote
            lastWriteError = nil
            return detail
        } catch {
            lastWriteError = RemoteServiceError.map(error)
            return nil
        }
    }

    func ticket(id: UUID) async throws -> RemoteSupportTicketDetail {
        guard let supportProvider else { throw RemoteServiceError.invalidRequest }
        return try await supportProvider.ticket(id: id)
    }

    func reply(ticketID: UUID, message: String, operationID: UUID) async -> RemoteSupportTicketReply? {
        guard let supportProvider else {
            lastWriteError = .invalidRequest
            return nil
        }
        isWriting = true
        defer { isWriting = false }
        do {
            let reply = try await supportProvider.reply(
                ticketID: ticketID,
                message: message,
                operationID: operationID
            )
            tickets.removeAll { $0.id == ticketID }
            tickets.insert(reply.ticket, at: 0)
            lastWriteError = nil
            return reply
        } catch {
            lastWriteError = RemoteServiceError.map(error)
            return nil
        }
    }

    func close(ticketID: UUID, operationID: UUID) async -> Bool {
        guard let supportProvider else {
            lastWriteError = .invalidRequest
            return false
        }
        isWriting = true
        defer { isWriting = false }
        do {
            let ticket = try await supportProvider.close(ticketID: ticketID, operationID: operationID)
            tickets.removeAll { $0.id == ticketID }
            tickets.insert(ticket, at: 0)
            lastWriteError = nil
            return true
        } catch {
            lastWriteError = RemoteServiceError.map(error)
            return false
        }
    }

    func leaderboard(challengeID: UUID, cursor: String?) async throws -> RemoteLeaderboard {
        guard let challengeProvider else { throw RemoteServiceError.invalidRequest }
        return try await challengeProvider.leaderboard(challengeID: challengeID, cursor: cursor)
    }

    func challenge(id: UUID, locale: String) async throws -> RemoteChallenge {
        guard let challengeProvider else { throw RemoteServiceError.invalidRequest }
        return try await challengeProvider.challenge(id: id, locale: locale)
    }

    func article(id: UUID, locale: String) async throws -> RemoteArticle {
        guard let contentProvider else { throw RemoteServiceError.invalidRequest }
        return try await contentProvider.article(id: id, locale: locale)
    }

    func helpArticle(id: UUID, locale: String) async throws -> RemoteHelpArticle {
        guard let supportProvider else { throw RemoteServiceError.invalidRequest }
        return try await supportProvider.helpArticle(id: id, locale: locale)
    }
}
