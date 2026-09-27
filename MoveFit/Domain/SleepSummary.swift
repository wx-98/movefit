import Foundation

enum SleepStage: String, CaseIterable {
    case inBed = "在床"
    case asleep = "睡眠"
    case awake = "清醒"
    case core = "核心"
    case deep = "深睡"
    case rem = "快速眼动"
}

struct SleepStageSegment: Identifiable, Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let stage: SleepStage

    var duration: TimeInterval { max(0, endDate.timeIntervalSince(startDate)) }
}

struct SleepSummary: Equatable {
    let startDate: Date
    let endDate: Date
    let totalSleep: TimeInterval
    let timeInBed: TimeInterval
    let awakeDuration: TimeInterval
    let coreDuration: TimeInterval
    let deepDuration: TimeInterval
    let remDuration: TimeInterval
    let efficiency: Double?
    let score: Int?
    let segments: [SleepStageSegment]
}

struct SleepScoreCalculator {
    func score(
        totalSleep: TimeInterval,
        timeInBed: TimeInterval,
        bedtimeDeviationMinutes: Double?
    ) -> Int? {
        guard totalSleep > 0, timeInBed >= totalSleep else { return nil }
        let hours = totalSleep / 3_600
        let durationScore: Double
        switch hours {
        case 7...9:
            durationScore = 60
        case 6..<7, 9..<10:
            durationScore = 48
        case 5..<6, 10..<11:
            durationScore = 35
        default:
            durationScore = 20
        }
        let efficiency = min(max(totalSleep / timeInBed, 0), 1)
        let efficiencyScore = efficiency * 25
        let regularityScore: Double
        if let deviation = bedtimeDeviationMinutes {
            regularityScore = max(0, 15 - min(deviation, 120) / 8)
        } else {
            regularityScore = 0
        }
        return Int((durationScore + efficiencyScore + regularityScore).rounded())
    }
}

struct SleepSummaryBuilder {
    func makeSummary(
        segments: [SleepStageSegment],
        bedtimeDeviationMinutes: Double? = nil
    ) -> SleepSummary? {
        let sorted = segments
            .filter { $0.endDate > $0.startDate }
            .sorted { $0.startDate < $1.startDate }
        guard let startDate = sorted.first?.startDate,
              let endDate = sorted.map(\.endDate).max() else { return nil }

        let asleepStages: Set<SleepStage> = [.asleep, .core, .deep, .rem]
        let totalSleep = unionDuration(of: sorted.filter { asleepStages.contains($0.stage) })
        let explicitInBed = unionDuration(of: sorted.filter { $0.stage == .inBed })
        let awake = unionDuration(of: sorted.filter { $0.stage == .awake })
        let timeInBed = max(explicitInBed, totalSleep + awake)
        guard totalSleep > 0, timeInBed > 0 else { return nil }

        return SleepSummary(
            startDate: startDate,
            endDate: endDate,
            totalSleep: totalSleep,
            timeInBed: timeInBed,
            awakeDuration: awake,
            coreDuration: unionDuration(of: sorted.filter { $0.stage == .core }),
            deepDuration: unionDuration(of: sorted.filter { $0.stage == .deep }),
            remDuration: unionDuration(of: sorted.filter { $0.stage == .rem }),
            efficiency: totalSleep / timeInBed,
            score: SleepScoreCalculator().score(
                totalSleep: totalSleep,
                timeInBed: timeInBed,
                bedtimeDeviationMinutes: bedtimeDeviationMinutes
            ),
            segments: sorted
        )
    }

    private func unionDuration(of segments: [SleepStageSegment]) -> TimeInterval {
        let sorted = segments.sorted { $0.startDate < $1.startDate }
        guard var currentStart = sorted.first?.startDate,
              var currentEnd = sorted.first?.endDate else { return 0 }
        var total: TimeInterval = 0

        for segment in sorted.dropFirst() {
            if segment.startDate <= currentEnd {
                currentEnd = max(currentEnd, segment.endDate)
            } else {
                total += currentEnd.timeIntervalSince(currentStart)
                currentStart = segment.startDate
                currentEnd = segment.endDate
            }
        }
        total += currentEnd.timeIntervalSince(currentStart)
        return total
    }
}
