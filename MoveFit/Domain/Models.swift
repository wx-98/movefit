import Foundation
import CoreLocation

enum WorkoutType: String, CaseIterable, Identifiable, Codable, Equatable {
    case running = "跑步"
    case walking = "步行"
    case cycling = "骑行"
    case yoga = "瑜伽"
    case strength = "力量"
    case hiit = "HIIT"
    case hiking = "徒步"
    case swimming = "游泳"
    case elliptical = "椭圆机"
    case rowing = "划船"
    case pilates = "普拉提"
    case dance = "舞蹈"
    case other = "其他"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .yoga: return "figure.mind.and.body"
        case .strength: return "dumbbell.fill"
        case .hiit: return "flame.fill"
        case .hiking: return "figure.walk"
        case .swimming: return "drop.fill"
        case .elliptical: return "circle.grid.cross"
        case .rowing: return "figure.walk"
        case .pilates: return "figure.mind.and.body"
        case .dance: return "music.note"
        case .other: return "circle.grid.2x2.fill"
        }
    }
}

struct HealthSummary: Equatable {
    let activeEnergy: Measurement<UnitEnergy>?
    let exerciseMinutes: Int?
    let standHours: Int?
    let steps: Int?
    let distance: Measurement<UnitLength>?
    let heartRate: Int?
    let restingHeartRate: Int?

    static let empty = HealthSummary(
        activeEnergy: nil,
        exerciseMinutes: nil,
        standHours: nil,
        steps: nil,
        distance: nil,
        heartRate: nil,
        restingHeartRate: nil
    )

    var hasAnyValue: Bool {
        activeEnergy != nil || exerciseMinutes != nil || standHours != nil || steps != nil
            || distance != nil || heartRate != nil || restingHeartRate != nil
    }
}

enum HealthDataStatus: Equatable {
    case notLoaded
    case unavailable
    case noData
    case available
    case failed
}

struct WorkoutRecord: Identifiable, Equatable {
    let id: UUID
    let type: WorkoutType
    let startedAt: Date
    let duration: TimeInterval
    let distance: Measurement<UnitLength>?
    let energy: Measurement<UnitEnergy>?
    let route: [CLLocationCoordinate2D]
    let source: WorkoutDataSource

    init(
        id: UUID,
        type: WorkoutType,
        startedAt: Date,
        duration: TimeInterval,
        distance: Measurement<UnitLength>?,
        energy: Measurement<UnitEnergy>?,
        route: [CLLocationCoordinate2D],
        source: WorkoutDataSource = .moveFit
    ) {
        self.id = id
        self.type = type
        self.startedAt = startedAt
        self.duration = duration
        self.distance = distance
        self.energy = energy
        self.route = route
        self.source = source
    }

    static func == (lhs: WorkoutRecord, rhs: WorkoutRecord) -> Bool { lhs.id == rhs.id }
}

struct WorkoutLocationSummary {
    let route: [CLLocationCoordinate2D]
    let distance: Measurement<UnitLength>?

    static let empty = WorkoutLocationSummary(route: [], distance: nil)
}

struct Challenge: Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let goal: Double
    var progress: Double?
    var isJoined: Bool
    let symbol: String
    let tint: ChallengeTint
    let unit: String
    let dataSource: String
    let rules: [String]
    let category: ChallengeCategory
    let difficulty: ChallengeDifficulty
    let metric: ChallengeMetric
    let isFeatured: Bool
}

enum ChallengeCategory: String, CaseIterable, Identifiable, Hashable {
    case running = "跑步"
    case cycling = "骑行"
    case strength = "力量"
    case hiit = "HIIT"
    case steps = "步数"
    case recovery = "恢复"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .strength: return "dumbbell.fill"
        case .hiit: return "flame.fill"
        case .steps: return "figure.walk"
        case .recovery: return "heart.text.square.fill"
        }
    }
}

enum ChallengeDifficulty: String, CaseIterable, Identifiable, Hashable {
    case beginner = "入门"
    case intermediate = "进阶"
    case goal = "目标"

    var id: String { rawValue }
}

enum ChallengeMetric: String {
    case steps
    case longestRunningDistance
    case totalCyclingDistance
    case strengthDays
    case hiitDays
    case recoveryDays
}

struct Badge: Identifiable {
    let id: UUID
    let title: String
    let symbol: String
    let isUnlocked: Bool
}

struct UserProfile: Equatable {
    var nickname: String
    var height: Measurement<UnitLength>
    var weight: Measurement<UnitMass>
    var bodyFatPercentage: Double

    var bmi: Double {
        let meters = height.converted(to: .meters).value
        return weight.converted(to: .kilograms).value / (meters * meters)
    }
}

enum AuthenticationMethod: String, CaseIterable, Identifiable {
    case apple = "Apple ID"
    case phone = "手机号"
    case email = "邮箱"
    case wechat = "微信"
    case google = "Google"

    var id: String { rawValue }
}

struct AccountSession: Equatable {
    let id: UUID
    let displayName: String
    let method: AuthenticationMethod
    let isLocalSimulation: Bool
}

enum AccountIdentifierKind: String, CaseIterable, Identifiable, Codable {
    case email
    case phone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .email: return "邮箱"
        case .phone: return "手机号"
        }
    }

    var authenticationMethod: AuthenticationMethod {
        switch self {
        case .email: return .email
        case .phone: return .phone
        }
    }
}

struct RemoteProfileSnapshot: Equatable {
    let nickname: String?
    let height: Measurement<UnitLength>?
    let weight: Measurement<UnitMass>?
    let bodyFatPercentage: Double?
    let version: Int
}

struct BackendClientConfiguration: Equatable {
    let schemaVersion: String
    let revision: Int
    let featureEnabled: Bool?
    let syncIntervalSeconds: Int?
}

enum BackendConnectionStatus: Equatable {
    case notLoaded
    case connected(revision: Int)
    case unavailable(message: String)
}

enum RemoteWorkoutSource: String {
    case manual
    case moveFitRecorded = "movefit_recorded"
}

struct WellnessArticle: Identifiable {
    let id: UUID
    let title: String
    let category: String
    let summary: String
    var isFavorite: Bool
}

enum HistoryPeriod: String, CaseIterable, Identifiable {
    case week = "周"
    case month = "月"
    case sixMonths = "六月"
    case year = "年"

    var id: String { rawValue }
}

enum WorkoutDataSource: String, Codable {
    case moveFit = "MoveFit"
    case appleHealth = "Apple 健康"
}

enum ChallengeTint: String, Equatable {
    case rose
    case blue
    case green
    case purple
    case orange
}
