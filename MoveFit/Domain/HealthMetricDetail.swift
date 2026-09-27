import Foundation

enum HomeHealthMetric: String, CaseIterable, Identifiable, Hashable {
    case steps
    case distance
    case heartRate
    case restingHeartRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: return "步数"
        case .distance: return "距离"
        case .heartRate: return "心率"
        case .restingHeartRate: return "静息心率"
        }
    }

    var symbol: String {
        switch self {
        case .steps: return "figure.walk"
        case .distance: return "location.fill"
        case .heartRate: return "heart.fill"
        case .restingHeartRate: return "waveform.path.ecg"
        }
    }

    var trendMetric: HealthTrendMetric {
        switch self {
        case .steps: return .steps
        case .distance: return .distance
        case .heartRate: return .heartRate
        case .restingHeartRate: return .restingHeartRate
        }
    }
}

struct HealthMetricDetail: Equatable {
    let metric: HomeHealthMetric
    let currentValue: Double?
    let unit: String
    let trend: HealthTrend
    let dataSource: String
    let lastUpdated: Date?

    var average: Double? { trend.average }
    var total: Double { trend.total }
}

enum ECGClassification: Equatable {
    case sinusRhythm
    case atrialFibrillation
    case inconclusive
    case unknown

    var title: String {
        switch self {
        case .sinusRhythm: return "窦性心律记录"
        case .atrialFibrillation: return "房颤提示记录"
        case .inconclusive: return "结果不明确"
        case .unknown: return "未分类记录"
        }
    }

    var safetyMessage: String {
        switch self {
        case .sinusRhythm:
            return "这是设备记录的分类，不替代医疗诊断。"
        case .atrialFibrillation:
            return "请留意身体感受；如有不适或担忧，请咨询合格医疗专业人员。"
        case .inconclusive, .unknown:
            return "设备没有提供明确分类；如有不适，请咨询合格医疗专业人员。"
        }
    }
}

struct ECGRecordSummary: Identifiable, Equatable {
    let id: UUID
    let recordedAt: Date
    let classification: ECGClassification
    let source: String
}

struct ECGWaveform: Equatable {
    let recordID: UUID
    let samplesInMicrovolts: [Double]

    static func downsample(recordID: UUID, samples: [Double], maximumCount: Int = 360) -> ECGWaveform {
        guard samples.count > maximumCount, maximumCount > 1 else {
            return ECGWaveform(recordID: recordID, samplesInMicrovolts: samples)
        }
        let stride = Double(samples.count - 1) / Double(maximumCount - 1)
        let reduced = (0..<maximumCount).map { index in
            samples[Int((Double(index) * stride).rounded(.down))]
        }
        return ECGWaveform(recordID: recordID, samplesInMicrovolts: reduced)
    }
}

enum HealthMetricDetailStatus: Equatable {
    case idle
    case loading
    case available
    case unavailable
    case noData
    case failed
}
