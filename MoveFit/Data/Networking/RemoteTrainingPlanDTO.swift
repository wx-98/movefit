import Foundation

enum RemoteTrainingPlanDTO {
    struct Page: Decodable {
        let items: [Item]
        let nextCursor: String?
        let hasMore: Bool
    }

    struct Item: Decodable {
        let trainingPlanId: UUID
        let slug: String
        let workoutType: String
        let difficulty: String
        let locale: String
        let revision: Int
        let title: String
        let subtitle: String
        let durationMinutes: Int
        let goal: String
        let suitableFor: String
        let steps: [Step]
        let safetyNotes: [String]
        let publishedAt: String
        let updatedAt: String

        func domain(expectedLocale: String) throws -> TrainingPlan {
            guard locale == expectedLocale,
                  slug.count <= 191,
                  slug.range(of: #"^[a-z0-9]+(?:-[a-z0-9]+)*$"#, options: .regularExpression) != nil,
                  revision > 0,
                  Self.hasText(title, maximum: 200),
                  Self.hasText(subtitle, maximum: 500),
                  Self.hasText(goal, maximum: 1_000),
                  Self.hasText(suitableFor, maximum: 1_000),
                  BackendDateParser.date(from: publishedAt) != nil,
                  BackendDateParser.date(from: updatedAt) != nil,
                  let type = Self.workoutType(from: workoutType),
                  let difficulty = Self.difficulty(from: difficulty),
                  (1...1_440).contains(durationMinutes),
                  (1...50).contains(steps.count),
                  (1...50).contains(safetyNotes.count),
                  safetyNotes.allSatisfy({ Self.hasText($0, maximum: 1_000) }),
                  steps.map(\.order) == Array(1...steps.count),
                  steps.allSatisfy({
                      (1...1_440).contains($0.durationMinutes)
                          && Self.hasText($0.title, maximum: 200)
                          && Self.hasText($0.detail, maximum: 2_000)
                  }),
                  steps.reduce(0, { $0 + $1.durationMinutes }) == durationMinutes else {
                throw BackendError.invalidResponse
            }
            let id = trainingPlanId.uuidString.lowercased()
            return TrainingPlan(
                id: id,
                type: type,
                title: title,
                subtitle: subtitle,
                difficulty: difficulty,
                durationMinutes: durationMinutes,
                goal: goal,
                suitableFor: suitableFor,
                steps: steps.map {
                    TrainingStep(
                        id: "\(id)-\($0.order)",
                        title: $0.title,
                        detail: $0.detail,
                        durationMinutes: $0.durationMinutes
                    )
                },
                safetyNotes: safetyNotes,
                tint: Self.tint(for: type)
            )
        }

        private static func hasText(_ value: String, maximum: Int) -> Bool {
            value.count <= maximum && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        private static func workoutType(from value: String) -> WorkoutType? {
            switch value {
            case "running": return .running
            case "walking": return .walking
            case "cycling": return .cycling
            case "strength": return .strength
            case "yoga": return .yoga
            case "hiit": return .hiit
            case "pilates": return .pilates
            default: return nil
            }
        }

        private static func difficulty(from value: String) -> TrainingDifficulty? {
            switch value {
            case "beginner": return .beginner
            case "intermediate": return .intermediate
            case "advanced": return .advanced
            default: return nil
            }
        }

        private static func tint(for type: WorkoutType) -> ChallengeTint {
            switch type {
            case .running, .hiit: return .rose
            case .walking, .yoga: return .green
            case .cycling: return .blue
            case .strength, .pilates: return .purple
            default: return .orange
            }
        }
    }

    struct Step: Decodable {
        let order: Int
        let title: String
        let detail: String
        let durationMinutes: Int
    }
}
