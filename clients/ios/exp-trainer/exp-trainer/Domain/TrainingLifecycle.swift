import Foundation

enum TrainingState: String, Codable, CaseIterable, Sendable {
    case draft
    case preparing
    case recording
    case paused
    case finishing
    case transcriptReview
    case completed
    case interrupted
    case abandoned
}

struct InvalidTrainingTransition: Error, Equatable, Sendable {
    let from: TrainingState
    let to: TrainingState
}

struct TrainingLifecycle: Equatable, Sendable {
    private(set) var state: TrainingState

    init(state: TrainingState = .draft) {
        self.state = state
    }

    mutating func transition(to newState: TrainingState) throws {
        guard canTransition(to: newState) else {
            throw InvalidTrainingTransition(from: state, to: newState)
        }
        state = newState
    }

    func canTransition(to newState: TrainingState) -> Bool {
        if newState == .abandoned {
            return state != .completed && state != .abandoned
        }

        return switch (state, newState) {
        case (.draft, .preparing),
             (.preparing, .recording),
             (.recording, .paused),
             (.paused, .recording),
             (.recording, .finishing),
             (.paused, .finishing),
             (.finishing, .transcriptReview),
             (.transcriptReview, .completed),
             (.preparing, .interrupted),
             (.recording, .interrupted),
             (.paused, .interrupted),
             (.interrupted, .recording),
             (.interrupted, .transcriptReview):
            true
        default:
            false
        }
    }
}
