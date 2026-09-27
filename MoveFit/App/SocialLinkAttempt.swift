import Foundation

enum SocialLinkAttempt {
    case provider(operationID: UUID, authorization: SocialAuthorization)
    case google(operationID: UUID, completion: GoogleAuthorizationCompletion)

    var operationID: UUID {
        switch self {
        case let .provider(operationID, _), let .google(operationID, _): return operationID
        }
    }
}
