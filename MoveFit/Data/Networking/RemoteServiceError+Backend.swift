import Foundation

extension RemoteServiceError {
    static func map(_ error: Error) -> RemoteServiceError {
        if let remoteError = error as? RemoteServiceError { return remoteError }
        guard let backend = error as? BackendError else { return .invalidResponse }
        switch backend {
        case .invalidRequest:
            return .invalidRequest
        case .networkUnavailable:
            return .networkUnavailable
        case .authenticationRequired, .invalidSession:
            return .authenticationRequired
        case let .server(status, code, _, retryAfterSeconds):
            return .server(status: status, code: code, retryAfterSeconds: retryAfterSeconds)
        case .invalidResponse, .unsupportedWorkoutType:
            return .invalidResponse
        }
    }
}
