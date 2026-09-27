import Foundation

enum HealthTrendMetric: String, CaseIterable, Identifiable {
    case steps
    case distance
    case activeEnergy
    case exerciseMinutes
    case heartRate
    case restingHeartRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: return "步数"
        case .distance: return "距离"
        case .activeEnergy: return "活动能量"
        case .exerciseMinutes: return "锻炼分钟"
        case .heartRate: return "心率"
        case .restingHeartRate: return "静息心率"
        }
    }

    var unit: String {
        switch self {
        case .steps: return "步"
        case .distance: return "公里"
        case .activeEnergy: return "千卡"
        case .exerciseMinutes: return "分钟"
        case .heartRate, .restingHeartRate: return "BPM"
        }
    }
}

enum HealthTrendPeriod: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case sixMonths = 180
    case year = 365

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .week: return "7 天"
        case .month: return "30 天"
        case .sixMonths: return "6 个月"
        case .year: return "1 年"
        }
    }
}

struct HealthTrendPoint: Identifiable, Equatable {
    let date: Date
    let value: Double?

    var id: Date { date }
}

struct HealthTrend: Equatable {
    let metric: HealthTrendMetric
    let period: HealthTrendPeriod
    let points: [HealthTrendPoint]

    static func empty(metric: HealthTrendMetric, period: HealthTrendPeriod) -> HealthTrend {
        HealthTrend(metric: metric, period: period, points: [])
    }

    var availablePoints: [HealthTrendPoint] { points.filter { $0.value != nil } }
    var total: Double { availablePoints.compactMap(\.value).reduce(0, +) }
    var average: Double? {
        guard !availablePoints.isEmpty else { return nil }
        return total / Double(availablePoints.count)
    }
    var bestPoint: HealthTrendPoint? {
        availablePoints.max { ($0.value ?? 0) < ($1.value ?? 0) }
    }
}
