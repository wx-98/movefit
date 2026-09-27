import Foundation

enum HealthInsightAccess: Equatable {
    case localOnly
    case upgradeRequired(productID: String)
    case remoteAvailable(capabilityVersion: String)
}

enum HealthInsightSource: Equatable {
    case localRule
    case remoteAI(modelVersion: String)

    var label: String {
        switch self {
        case .localRule: return "本地趋势洞察"
        case let .remoteAI(modelVersion): return "AI 洞察 · \(modelVersion)"
        }
    }
}

struct HealthInsightRequest: Equatable {
    let metric: HomeHealthMetric
    let currentValue: Double?
    let averageValue: Double?
    let unit: String
    let period: HealthTrendPeriod
    let generatedAt: Date
}

struct HealthInsight: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String
    let source: HealthInsightSource
    let generatedAt: Date
    let safetyNotice: String
}

protocol AIHealthInsightProviding {
    func access(for metric: HomeHealthMetric) async -> HealthInsightAccess
    func analyze(_ request: HealthInsightRequest) async throws -> [HealthInsight]
}

struct LocalHealthInsightProvider: AIHealthInsightProviding {
    func access(for metric: HomeHealthMetric) async -> HealthInsightAccess { .localOnly }

    func analyze(_ request: HealthInsightRequest) async throws -> [HealthInsight] {
        guard let current = request.currentValue else {
            return [HealthInsight(
                id: UUID(),
                title: "补充数据后可获得更具体的洞察",
                message: "连接 Apple 健康并积累一段时间的\(request.metric.title)数据后，MoveFit 可以提供趋势说明。",
                source: .localRule,
                generatedAt: request.generatedAt,
                safetyNotice: "内容仅供健康管理参考，不替代医疗建议。"
            )]
        }

        let comparison: String
        if let average = request.averageValue {
            let threshold = max(1, average * 0.05)
            if abs(current - average) < threshold {
                comparison = "当前数值与近期平均水平接近。"
            } else if current > average {
                comparison = "当前数值高于近期平均水平。"
            } else {
                comparison = "当前数值低于近期平均水平。"
            }
        } else {
            comparison = "近期数据不足，暂不做平均值比较。"
        }

        let digits = request.metric == .distance ? 1 : 0
        let value = String(format: "%.*f", digits, current)
        return [HealthInsight(
            id: UUID(),
            title: "\(request.metric.title)趋势",
            message: "当前为 \(value) \(request.unit)。\(comparison)",
            source: .localRule,
            generatedAt: request.generatedAt,
            safetyNotice: safetyNotice(for: request.metric)
        )]
    }

    private func safetyNotice(for metric: HomeHealthMetric) -> String {
        switch metric {
        case .heartRate, .restingHeartRate:
            return "心率会受活动、睡眠、情绪和药物等因素影响；如有不适或担忧，请咨询合格医疗专业人员。"
        case .steps, .distance:
            return "内容仅供健康管理参考，请按自身状态安排活动。"
        }
    }
}
