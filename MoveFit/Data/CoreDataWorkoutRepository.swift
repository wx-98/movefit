import Foundation

actor CoreDataWorkoutRepository: WorkoutRepository {
    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }

    func workouts() async throws -> [WorkoutRecord] {
        try await persistenceController.loadWorkouts()
    }

    func save(_ workout: WorkoutRecord, operationID: UUID) async throws {
        try await persistenceController.save(workout: workout, operationID: operationID)
    }
}
