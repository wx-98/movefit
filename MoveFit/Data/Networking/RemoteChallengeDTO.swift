import Foundation

enum RemoteChallengeDTO {
    struct Item: Decodable {
        let challengeId: UUID
        let title: String
        let summary: String
        let metric: String
        let goalValue: Double
        let goalUnit: String
        let startsAt: String
        let endsAt: String
        let enrollmentOpensAt: String
        let enrollmentClosesAt: String
        let exitClosesAt: String?
        let eligibleWorkoutTypes: [String]
        let eligibleWorkoutSources: [String]
        let ruleVersion: Int

        func domain() throws -> RemoteChallenge {
            guard let startsAt = BackendDateParser.date(from: startsAt),
                  let endsAt = BackendDateParser.date(from: endsAt),
                  let enrollmentOpensAt = BackendDateParser.date(from: enrollmentOpensAt),
                  let enrollmentClosesAt = BackendDateParser.date(from: enrollmentClosesAt) else {
                throw BackendError.invalidResponse
            }
            let exitDate: Date?
            if let exitClosesAt {
                guard let parsed = BackendDateParser.date(from: exitClosesAt) else {
                    throw BackendError.invalidResponse
                }
                exitDate = parsed
            } else {
                exitDate = nil
            }
            return RemoteChallenge(
                id: challengeId,
                title: title,
                summary: summary,
                metric: metric,
                goalValue: goalValue,
                goalUnit: goalUnit,
                startsAt: startsAt,
                endsAt: endsAt,
                enrollmentOpensAt: enrollmentOpensAt,
                enrollmentClosesAt: enrollmentClosesAt,
                exitClosesAt: exitDate,
                eligibleWorkoutTypes: eligibleWorkoutTypes,
                eligibleWorkoutSources: eligibleWorkoutSources,
                ruleVersion: ruleVersion
            )
        }
    }

    struct Participation: Decodable {
        let participationId: UUID
        let challengeId: UUID
        let status: String
        let progressValue: Double
        let goalValue: Double
        let goalUnit: String
        let isComplete: Bool
        let calculatedAt: String

        func domain() throws -> RemoteChallengeParticipation {
            guard let calculatedAt = BackendDateParser.date(from: calculatedAt) else {
                throw BackendError.invalidResponse
            }
            return RemoteChallengeParticipation(
                id: participationId,
                challengeID: challengeId,
                status: status,
                progressValue: progressValue,
                goalValue: goalValue,
                goalUnit: goalUnit,
                isComplete: isComplete,
                calculatedAt: calculatedAt
            )
        }
    }

    struct LeaderboardEntry: Decodable {
        let rank: Int
        let displayAlias: String
        let progressValue: Double
        let goalUnit: String
        let isCurrentUser: Bool

        func domain() throws -> RemoteLeaderboardEntry {
            guard displayAlias.hasPrefix("Mover-"), rank > 0, progressValue >= 0 else {
                throw BackendError.invalidResponse
            }
            return RemoteLeaderboardEntry(
                rank: rank,
                displayAlias: displayAlias,
                progressValue: progressValue,
                goalUnit: goalUnit,
                isCurrentUser: isCurrentUser
            )
        }
    }

    struct Leaderboard: Decodable {
        let snapshotGeneratedAt: String
        let items: [LeaderboardEntry]
        let nextCursor: String?
        let hasMore: Bool

        func domain() throws -> RemoteLeaderboard {
            guard let generatedAt = BackendDateParser.date(from: snapshotGeneratedAt) else {
                throw BackendError.invalidResponse
            }
            return RemoteLeaderboard(
                snapshotGeneratedAt: generatedAt,
                entries: try items.map { try $0.domain() },
                nextCursor: nextCursor,
                hasMore: hasMore
            )
        }
    }

    struct JoinRequest: Encodable {
        let locale: String
    }
}
