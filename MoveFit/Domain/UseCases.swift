import Foundation

struct LoadWorkoutsUseCase {
    let repository: WorkoutRepository
    func execute() async throws -> [WorkoutRecord] { try await repository.workouts() }
}

struct SaveWorkoutUseCase {
    let repository: WorkoutRepository
    func execute(_ workout: WorkoutRecord, operationID: UUID) async throws {
        try await repository.save(workout, operationID: operationID)
    }
}

struct LoadDailyHealthUseCase {
    let provider: HealthDataProviding
    func execute() async throws -> HealthSummary? { try await provider.dailySummary() }
}
