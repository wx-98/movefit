import Foundation

enum RemoteServiceError: Error, Equatable {
    case invalidRequest
    case networkUnavailable
    case authenticationRequired
    case invalidResponse
    case server(status: Int, code: String?, retryAfterSeconds: Int?)
}
