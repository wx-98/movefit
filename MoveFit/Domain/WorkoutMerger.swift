import Foundation

struct WorkoutMerger {
    func merge(
        local: [WorkoutRecord],
        health: [WorkoutRecord],
        remote: [WorkoutRecord] = []
    ) -> [WorkoutRecord] {
        var records: [String: WorkoutRecord] = [:]
        (local + health + remote).forEach { workout in
            records["\(workout.source.rawValue):\(workout.id.uuidString)"] = workout
        }
        return records.values.sorted { $0.startedAt > $1.startedAt }
    }
}
