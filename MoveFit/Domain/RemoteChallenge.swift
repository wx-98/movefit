import Foundation

struct RemoteChallenge: Identifiable {
    let id: UUID
    let title: String
    let summary: String
    let metric: String
    let goalValue: Double
    let goalUnit: String
    let startsAt: Date
    let endsAt: Date
    let enrollmentOpensAt: Date
    let enrollmentClosesAt: Date
    let exitClosesAt: Date?
    let eligibleWorkoutTypes: [String]
    let eligibleWorkoutSources: [String]
    let ruleVersion: Int
}

struct RemoteChallengeParticipation: Identifiable {
    let id: UUID
    let challengeID: UUID
    let status: String
    let progressValue: Double
    let goalValue: Double
    let goalUnit: String
    let isComplete: Bool
    let calculatedAt: Date
}

struct RemoteLeaderboardEntry {
    let rank: Int
    let displayAlias: String
    let progressValue: Double
    let goalUnit: String
    let isCurrentUser: Bool
}

struct RemoteLeaderboard {
    let snapshotGeneratedAt: Date
    let entries: [RemoteLeaderboardEntry]
    let nextCursor: String?
    let hasMore: Bool
}
