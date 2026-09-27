import Foundation

struct RemoteAIHealthInsightRepository: AIHealthInsightProviding {
    private let client: AIHealthInsightAPIClient

    init(client: AIHealthInsightAPIClient) {
        self.client = client
    }

    func access(for metric: HomeHealthMetric) async -> HealthInsightAccess {
        do {
            let response = try await client.access(metric: metric.aiMetricName)
            switch response.access {
            case "remote_available":
                return .remoteAvailable(capabilityVersion: response.capabilityVersion ?? "未知版本")
            case "upgrade_required":
                return .upgradeRequired(productID: "ai_health_insights")
            default:
                return .localOnly
            }
        } catch {
            return .localOnly
        }
    }

    func analyze(_ request: HealthInsightRequest) async throws -> [HealthInsight] {
        struct AnalyzeBody: Encodable {
            let metric: String
            let currentValue: Double?
            let averageValue: Double?
            let unit: String
            let period: String
        }
        let response = try await client.analyze(
            AnalyzeBody(
                metric: request.metric.aiMetricName,
                currentValue: request.currentValue,
                averageValue: request.averageValue,
                unit: request.unit.lowercased(),
                period: request.period.aiPeriodName
            ),
            idempotencyKey: UUID()
        )
        return response.insights.compactMap { item in
            guard let generatedAt = BackendDateParser.date(from: item.generatedAt) else { return nil }
            return HealthInsight(
                id: item.id,
                title: item.title,
                message: item.message,
                source: .remoteAI(modelVersion: item.modelVersion),
                generatedAt: generatedAt,
                safetyNotice: item.safetyNotice
            )
        }
    }
}

private extension HomeHealthMetric {
    var aiMetricName: String {
        switch self {
        case .steps: return "steps"
        case .distance: return "distance"
        case .heartRate: return "heart_rate"
        case .restingHeartRate: return "resting_heart_rate"
        }
    }
}

private extension HealthTrendPeriod {
    var aiPeriodName: String {
        switch self {
        case .week: return "week"
        case .month, .sixMonths, .year: return "month"
        }
    }
}
