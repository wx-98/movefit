import Foundation

enum HistoryTrendBucketGranularity {
    case day
    case week
    case month
}

struct HistoryTrendBucket: Identifiable, Equatable {
    let startDate: Date
    let endDate: Date
    let value: Double?
    let label: String

    var id: Date { startDate }
}

struct HistoryTrendBucketer {
    func buckets(
        for trend: HealthTrend,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> [HistoryTrendBucket] {
        var calendar = calendar
        calendar.timeZone = timeZone
        let granularity = granularity(for: trend.period)
        let grouped = Dictionary(grouping: trend.points) { point in
            bucketStart(for: point.date, granularity: granularity, calendar: calendar)
        }
        return grouped.keys.sorted().compactMap { startDate in
            guard let endDate = bucketEnd(
                for: startDate,
                granularity: granularity,
                calendar: calendar
            ) else {
                return nil
            }
            let values = grouped[startDate]?.compactMap(\.value) ?? []
            return HistoryTrendBucket(
                startDate: startDate,
                endDate: endDate,
                value: values.isEmpty ? nil : values.reduce(0, +),
                label: label(for: startDate, granularity: granularity, calendar: calendar)
            )
        }
    }

    private func granularity(for period: HealthTrendPeriod) -> HistoryTrendBucketGranularity {
        switch period {
        case .week: return .day
        case .month: return .week
        case .sixMonths, .year: return .month
        }
    }

    private func bucketStart(
        for date: Date,
        granularity: HistoryTrendBucketGranularity,
        calendar: Calendar
    ) -> Date {
        switch granularity {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    private func bucketEnd(
        for startDate: Date,
        granularity: HistoryTrendBucketGranularity,
        calendar: Calendar
    ) -> Date? {
        switch granularity {
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: startDate)
        case .week:
            return calendar.date(byAdding: .day, value: 7, to: startDate)
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: startDate)
        }
    }

    private func label(
        for date: Date,
        granularity: HistoryTrendBucketGranularity,
        calendar: Calendar
    ) -> String {
        switch granularity {
        case .day:
            return date.formatted(.dateTime.weekday(.narrow))
        case .week:
            return "\(calendar.component(.month, from: date))/\(calendar.component(.day, from: date))"
        case .month:
            return "\(calendar.component(.month, from: date))月"
        }
    }
}

struct HistoryTrendComparison {
    let average: Double?
    let todayValue: Double?

    init(points: [HealthTrendPoint], calendar: Calendar, timeZone: TimeZone, now: Date) {
        var calendar = calendar
        calendar.timeZone = timeZone
        let values = points.compactMap(\.value)
        average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        todayValue = points.last(where: { calendar.isDate($0.date, inSameDayAs: now) })?.value
    }

    var message: String {
        guard let average, let todayValue else { return "数据不足，暂不能比较今天与平均水平。" }
        let difference = todayValue - average
        if abs(difference) < max(100, average * 0.05) {
            return "今天步数与当前周期平均水平接近。"
        }
        return difference > 0 ? "今天步数高于当前周期平均水平。" : "今天步数低于当前周期平均水平。"
    }
}
