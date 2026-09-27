import Foundation

enum WorkoutSessionState: Equatable {
    case idle
    case preparing(WorkoutType)
    case running(WorkoutType, startedAt: Date, accumulated: TimeInterval)
    case paused(WorkoutType, accumulated: TimeInterval)
    case saving
    case completed(UUID)
    case failed(String)
}

enum WorkoutSessionAction {
    case prepare(WorkoutType)
    case start(Date)
    case pause(TimeInterval)
    case resume(Date)
    case finish
    case saved(UUID)
    case fail(String)
    case cancel
    case reset
}

struct WorkoutSessionStateMachine {
    private(set) var state: WorkoutSessionState = .idle

    @discardableResult
    mutating func send(_ action: WorkoutSessionAction) -> Bool {
        switch (state, action) {
        case (.idle, .prepare(let type)):
            state = .preparing(type)
        case (.preparing(let type), .start(let date)):
            state = .running(type, startedAt: date, accumulated: 0)
        case (.running(let type, _, _), .pause(let elapsed)):
            state = .paused(type, accumulated: elapsed)
        case (.paused(let type, let accumulated), .resume(let date)):
            state = .running(type, startedAt: date, accumulated: accumulated)
        case (.running, .finish), (.paused, .finish):
            state = .saving
        case (.saving, .saved(let id)):
            state = .completed(id)
        case (.saving, .fail(let message)):
            state = .failed(message)
        case (.preparing, .cancel), (.running, .cancel), (.paused, .cancel):
            state = .idle
        case (.completed, .reset), (.failed, .reset):
            state = .idle
        default:
            return false
        }
        return true
    }
}
