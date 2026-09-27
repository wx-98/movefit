import Foundation

struct Exercise: Identifiable, Equatable {
    let id: String
    let name: String
    let originalName: String
    let difficulty: TrainingDifficulty
    let equipment: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let safetyNotes: [String]
    let sourceVersion: String
    let imageURLs: [URL]

    init(
        id: String,
        name: String,
        originalName: String,
        difficulty: TrainingDifficulty,
        equipment: String,
        primaryMuscles: [String],
        secondaryMuscles: [String],
        instructions: [String],
        safetyNotes: [String],
        sourceVersion: String,
        imageURLs: [URL] = []
    ) {
        self.id = id
        self.name = name
        self.originalName = originalName
        self.difficulty = difficulty
        self.equipment = equipment
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.instructions = instructions
        self.safetyNotes = safetyNotes
        self.sourceVersion = sourceVersion
        self.imageURLs = imageURLs
    }
}

struct ExerciseCatalogQuery: Equatable {
    var text = ""
    var equipment: String?
    var muscle: String?
    var difficulty: TrainingDifficulty?
}

struct ExerciseCatalogPage: Equatable {
    let exercises: [Exercise]
    let sourceVersion: String
    let hasMore: Bool
    let source: ExerciseCatalogSource

    init(
        exercises: [Exercise],
        sourceVersion: String,
        hasMore: Bool,
        source: ExerciseCatalogSource = .remote
    ) {
        self.exercises = exercises
        self.sourceVersion = sourceVersion
        self.hasMore = hasMore
        self.source = source
    }
}

enum ExerciseCatalogSource: Equatable {
    case remote
    case bundledFallback(message: String)
}

enum ExerciseCatalogStatus: Equatable {
    case loading
    case bundledOnly
    case available(version: String)
    case failed
}
