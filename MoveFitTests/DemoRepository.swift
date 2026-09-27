import CoreLocation
import Foundation
@testable import MoveFit

actor DemoWorkoutRepository: WorkoutRepository {
    private var records: [WorkoutRecord]
    private var appliedOperations = Set<UUID>()
    private let persistenceController: PersistenceController?

    init(persistenceController: PersistenceController? = nil) {
        self.persistenceController = persistenceController
        records = [
            WorkoutRecord(
                id: UUID(), type: .running, startedAt: Date().addingTimeInterval(-3_600), duration: 1_934,
                distance: Measurement(value: 6.8, unit: .kilometers),
                energy: Measurement(value: 420, unit: .kilocalories),
                route: [
                    CLLocationCoordinate2D(latitude: 39.9940, longitude: 116.4740),
                    CLLocationCoordinate2D(latitude: 39.9912, longitude: 116.4795),
                    CLLocationCoordinate2D(latitude: 39.9870, longitude: 116.4820),
                    CLLocationCoordinate2D(latitude: 39.9835, longitude: 116.4770)
                ]
            ),
            WorkoutRecord(
                id: UUID(), type: .yoga, startedAt: Date().addingTimeInterval(-90_000), duration: 2_700,
                distance: nil, energy: Measurement(value: 180, unit: .kilocalories), route: []
            )
        ]
    }

    func workouts() async throws -> [WorkoutRecord] {
        let persisted = try await persistenceController?.loadWorkouts() ?? []
        return (records + persisted).sorted { $0.startedAt > $1.startedAt }
    }

    func save(_ workout: WorkoutRecord, operationID: UUID) async throws {
        if let persistenceController = persistenceController {
            try await persistenceController.save(workout: workout, operationID: operationID)
            return
        }
        guard appliedOperations.insert(operationID).inserted else { return }
        if !records.contains(where: { $0.id == workout.id }) { records.append(workout) }
    }
}

struct DemoHealthProvider: HealthDataProviding {
    let isAvailable = true
    func requestAuthorization() async throws {}
    func dailySummary() async throws -> HealthSummary? {
        HealthSummary(
            activeEnergy: Measurement(value: 450, unit: .kilocalories), exerciseMinutes: 32, standHours: 8,
            steps: 6_243, distance: Measurement(value: 4.2, unit: .kilometers), heartRate: 72, restingHeartRate: 61
        )
    }
}
