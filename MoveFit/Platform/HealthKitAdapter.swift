import HealthKit

final class HealthKitAdapter: HealthDataProviding {
    private let store: HKHealthStore
    private let calendar: Calendar
    private let now: () -> Date

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    init(
        store: HKHealthStore = HKHealthStore(),
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.calendar = calendar
        self.now = now
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthDataError.platformUnavailable }
        var requestedTypes: [HKObjectType?] = [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.categoryType(forIdentifier: .appleStandHour),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType()
        ]
        requestedTypes.append(HKObjectType.electrocardiogramType())
        let types = Set(requestedTypes.compactMap { $0 })
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [], read: types) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthDataError.authorizationUnavailable)
                }
            }
        }
    }

    func dailySummary() async throws -> HealthSummary? {
        guard isAvailable else { return nil }
        let endDate = now()
        let startDate = calendar.startOfDay(for: endDate)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        async let stepsValue = cumulativeValue(for: .stepCount, unit: .count(), predicate: predicate)
        async let distanceValue = cumulativeValue(for: .distanceWalkingRunning, unit: .meter(), predicate: predicate)
        async let energyValue = cumulativeValue(for: .activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)
        async let exerciseValue = cumulativeValue(for: .appleExerciseTime, unit: .minute(), predicate: predicate)
        async let standValue = standHours(predicate: predicate)
        async let heartRateValue = latestValue(
            for: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            predicate: predicate
        )
        async let restingHeartRateValue = latestValue(
            for: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            predicate: predicate
        )

        let values = try await (
            stepsValue,
            distanceValue,
            energyValue,
            exerciseValue,
            standValue,
            heartRateValue,
            restingHeartRateValue
        )
        let summary = HealthSummary(
            activeEnergy: values.2.map { Measurement(value: $0, unit: .kilocalories) },
            exerciseMinutes: values.3.map { Int($0.rounded()) },
            standHours: values.4,
            steps: values.0.map { Int($0.rounded()) },
            distance: values.1.map { Measurement(value: $0, unit: .meters) },
            heartRate: values.5.map { Int($0.rounded()) },
            restingHeartRate: values.6.map { Int($0.rounded()) }
        )
        return summary.hasAnyValue ? summary : nil
    }

    func trend(metric: HealthTrendMetric, period: HealthTrendPeriod) async throws -> HealthTrend {
        guard isAvailable else { return .empty(metric: metric, period: period) }
        let endDate = now()
        let startOfToday = calendar.startOfDay(for: endDate)
        guard let startDate = calendar.date(
            byAdding: .day,
            value: -(period.rawValue - 1),
            to: startOfToday
        ) else {
            return .empty(metric: metric, period: period)
        }
        let configuration = try trendConfiguration(for: metric)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: configuration.type,
                quantitySamplePredicate: predicate,
                options: configuration.options,
                anchorDate: startOfToday,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var points: [HealthTrendPoint] = []
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let quantity = configuration.usesCumulativeSum
                        ? statistics.sumQuantity()
                        : statistics.averageQuantity()
                    let value = quantity?.doubleValue(for: configuration.unit)
                    points.append(HealthTrendPoint(date: statistics.startDate, value: value))
                }
                continuation.resume(
                    returning: HealthTrend(metric: metric, period: period, points: points)
                )
            }
            store.execute(query)
        }
    }

    func metricDetail(for metric: HomeHealthMetric) async throws -> HealthMetricDetail? {
        guard isAvailable else { return nil }
        let summary = try await dailySummary()
        let trend = try await trend(metric: metric.trendMetric, period: .month)
        let currentValue: Double?
        let unit: String
        switch metric {
        case .steps:
            currentValue = summary?.steps.map(Double.init)
            unit = "步"
        case .distance:
            currentValue = summary?.distance?.converted(to: .kilometers).value
            unit = "公里"
        case .heartRate:
            currentValue = summary?.heartRate.map(Double.init)
            unit = "BPM"
        case .restingHeartRate:
            currentValue = summary?.restingHeartRate.map(Double.init)
            unit = "BPM"
        }
        return HealthMetricDetail(
            metric: metric,
            currentValue: currentValue,
            unit: unit,
            trend: trend,
            dataSource: "Apple 健康",
            lastUpdated: currentValue == nil && trend.availablePoints.isEmpty ? nil : now()
        )
    }

    func electrocardiogramSummaries() async throws -> [ECGRecordSummary] {
        guard isAvailable else { return [] }
        let type = HKObjectType.electrocardiogramType()
        let samples: [HKElectrocardiogram] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 12,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKElectrocardiogram] ?? [])
                }
            }
            store.execute(query)
        }
        return samples.map { sample in
            ECGRecordSummary(
                id: sample.uuid,
                recordedAt: sample.startDate,
                classification: ecgClassification(for: sample),
                source: sample.sourceRevision.source.name
            )
        }
    }

    func electrocardiogramWaveform(for recordID: UUID) async throws -> ECGWaveform? {
        guard isAvailable else { return nil }
        let type = HKObjectType.electrocardiogramType()
        let predicate = HKQuery.predicateForObject(with: recordID)
        let sample: HKElectrocardiogram? = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples?.first as? HKElectrocardiogram) }
            }
            store.execute(query)
        }
        guard let sample else { return nil }
        let samples: [Double] = try await withCheckedThrowingContinuation { continuation in
            var values: [Double] = []
            let query = HKElectrocardiogramQuery(electrocardiogram: sample) { _, measurement, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let measurement {
                    if let quantity = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                        values.append(quantity.doubleValue(for: HKUnit.voltUnit(with: .micro)))
                    }
                }
                if done {
                    continuation.resume(returning: values)
                }
            }
            store.execute(query)
        }
        return samples.isEmpty ? nil : ECGWaveform.downsample(recordID: recordID, samples: samples)
    }

    func sleepSummary() async throws -> SleepSummary? {
        guard isAvailable,
              let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let startDate = calendar.date(byAdding: .day, value: -8, to: now()) else { return nil }
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now(),
            options: .strictEndDate
        )
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }
            store.execute(query)
        }
        let segments = samples.compactMap(makeSleepSegment)
        let sessions = makeSleepSessions(from: segments)
        guard let latest = sessions.last else { return nil }
        let deviation = bedtimeDeviation(for: sessions)
        return SleepSummaryBuilder().makeSummary(
            segments: latest,
            bedtimeDeviationMinutes: deviation
        )
    }

    func healthWorkouts() async throws -> [WorkoutRecord] {
        guard isAvailable else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let workouts = (samples as? [HKWorkout] ?? []).map(Self.makeWorkout)
                    continuation.resume(returning: workouts)
                }
            }
            store.execute(query)
        }
    }

    private func cumulativeValue(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthDataError.dataTypeUnavailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
                }
            }
            store.execute(query)
        }
    }

    private func latestValue(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthDataError.dataTypeUnavailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let sample = samples?.first as? HKQuantitySample
                    continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
                }
            }
            store.execute(query)
        }
    }

    private func standHours(predicate: NSPredicate) async throws -> Int? {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else {
            throw HealthDataError.dataTypeUnavailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let stoodValue = HKCategoryValueAppleStandHour.stood.rawValue
                    let count = (samples as? [HKCategorySample])?.filter { $0.value == stoodValue }.count
                    continuation.resume(returning: count == 0 ? nil : count)
                }
            }
            store.execute(query)
        }
    }

    private func trendConfiguration(
        for metric: HealthTrendMetric
    ) throws -> (type: HKQuantityType, unit: HKUnit, options: HKStatisticsOptions, usesCumulativeSum: Bool) {
        let identifier: HKQuantityTypeIdentifier
        let unit: HKUnit
        let options: HKStatisticsOptions
        let usesCumulativeSum: Bool
        switch metric {
        case .steps:
            identifier = .stepCount
            unit = .count()
            options = .cumulativeSum
            usesCumulativeSum = true
        case .distance:
            identifier = .distanceWalkingRunning
            unit = .meterUnit(with: .kilo)
            options = .cumulativeSum
            usesCumulativeSum = true
        case .activeEnergy:
            identifier = .activeEnergyBurned
            unit = .kilocalorie()
            options = .cumulativeSum
            usesCumulativeSum = true
        case .exerciseMinutes:
            identifier = .appleExerciseTime
            unit = .minute()
            options = .cumulativeSum
            usesCumulativeSum = true
        case .heartRate:
            identifier = .heartRate
            unit = HKUnit.count().unitDivided(by: .minute())
            options = .discreteAverage
            usesCumulativeSum = false
        case .restingHeartRate:
            identifier = .restingHeartRate
            unit = HKUnit.count().unitDivided(by: .minute())
            options = .discreteAverage
            usesCumulativeSum = false
        }
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthDataError.dataTypeUnavailable
        }
        return (type, unit, options, usesCumulativeSum)
    }

    private func ecgClassification(for sample: HKElectrocardiogram) -> ECGClassification {
        let description = String(describing: sample.classification)
        if description.contains("sinusRhythm") { return .sinusRhythm }
        if description.contains("atrialFibrillation") { return .atrialFibrillation }
        if description.contains("inconclusive") { return .inconclusive }
        return .unknown
    }

    func makeSleepSegment(from sample: HKCategorySample) -> SleepStageSegment? {
        let stage: SleepStage
        switch sample.value {
        case 0: stage = .inBed
        case 1: stage = .asleep
        case 2: stage = .awake
        case 3: stage = .core
        case 4: stage = .deep
        case 5: stage = .rem
        default: return nil
        }
        return SleepStageSegment(
            id: sample.uuid,
            startDate: sample.startDate,
            endDate: sample.endDate,
            stage: stage
        )
    }

    func makeSleepSessions(
        from segments: [SleepStageSegment]
    ) -> [[SleepStageSegment]] {
        var sessions: [[SleepStageSegment]] = []
        for segment in segments.sorted(by: { $0.startDate < $1.startDate }) {
            guard let lastEnd = sessions.last?.map(\.endDate).max(),
                  segment.startDate.timeIntervalSince(lastEnd) <= 4 * 3_600 else {
                sessions.append([segment])
                continue
            }
            sessions[sessions.count - 1].append(segment)
        }
        return sessions
    }

    func bedtimeDeviation(for sessions: [[SleepStageSegment]]) -> Double? {
        guard sessions.count > 1,
              let latestStart = sessions.last?.map(\.startDate).min() else { return nil }
        let latestMinutes = minutesSinceMidnight(latestStart)
        let deviations = sessions.dropLast().compactMap { session -> Double? in
            guard let start = session.map(\.startDate).min() else { return nil }
            let difference = abs(Double(minutesSinceMidnight(start) - latestMinutes))
            return min(difference, 1_440 - difference)
        }
        guard !deviations.isEmpty else { return nil }
        return deviations.reduce(0, +) / Double(deviations.count)
    }

    private func minutesSinceMidnight(_ date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func makeWorkout(from workout: HKWorkout) -> WorkoutRecord {
        let distance = workout.totalDistance.map {
            Measurement(value: $0.doubleValue(for: .meter()), unit: UnitLength.meters)
        }
        let energy = workout.totalEnergyBurned.map {
            Measurement(value: $0.doubleValue(for: .kilocalorie()), unit: UnitEnergy.kilocalories)
        }
        return WorkoutRecord(
            id: workout.uuid,
            type: mapWorkoutType(workout.workoutActivityType),
            startedAt: workout.startDate,
            duration: workout.duration,
            distance: distance,
            energy: energy,
            route: [],
            source: .appleHealth
        )
    }

    static func mapWorkoutType(_ type: HKWorkoutActivityType) -> WorkoutType {
        switch type {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .yoga: return .yoga
        case .traditionalStrengthTraining, .functionalStrengthTraining: return .strength
        case .highIntensityIntervalTraining: return .hiit
        case .hiking: return .hiking
        case .swimming: return .swimming
        case .elliptical: return .elliptical
        case .rowing: return .rowing
        case .pilates: return .pilates
        case .dance: return .dance
        default: return .other
        }
    }
}

enum HealthDataError: Error {
    case platformUnavailable
    case authorizationUnavailable
    case dataTypeUnavailable
}
