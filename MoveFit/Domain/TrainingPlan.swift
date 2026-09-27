import Foundation

enum TrainingDifficulty: String, CaseIterable, Identifiable, Codable {
    case beginner = "入门"
    case intermediate = "进阶"
    case advanced = "高阶"

    var id: String { rawValue }
}

struct TrainingStep: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let durationMinutes: Int
}

struct TrainingPlan: Identifiable, Equatable {
    let id: String
    let type: WorkoutType
    let title: String
    let subtitle: String
    let difficulty: TrainingDifficulty
    let durationMinutes: Int
    let goal: String
    let suitableFor: String
    let steps: [TrainingStep]
    let safetyNotes: [String]
    let tint: ChallengeTint
}
