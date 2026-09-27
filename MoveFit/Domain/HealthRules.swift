import Foundation

struct ActivityAggregator {
    func totalSteps(_ dailySteps: [Int]) -> Int {
        dailySteps.reduce(0) { $0 + max(0, $1) }
    }

    func averageDailySteps(_ dailySteps: [Int]) -> Int {
        guard !dailySteps.isEmpty else { return 0 }
        return totalSteps(dailySteps) / dailySteps.count
    }
}

struct ChallengeProgressCalculator {
    func ratio(progress: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(progress / goal, 0), 1)
    }
}

enum WellnessRecommendation: String, Equatable {
    case increaseActivity = "今天可增加一段轻中强度活动。"
    case keepRecovery = "今日活动量充足，记得安排拉伸与恢复。"
    case addStandBreak = "久坐期间每小时起身活动一次。"
}

struct WellnessRuleEngine {
    func recommendations(for summary: HealthSummary) -> [WellnessRecommendation] {
        var result: [WellnessRecommendation] = []
        if let exerciseMinutes = summary.exerciseMinutes {
            result.append(exerciseMinutes < 30 ? .increaseActivity : .keepRecovery)
        }
        if let standHours = summary.standHours, standHours < 8 {
            result.append(.addStandBreak)
        }
        return result
    }
}
