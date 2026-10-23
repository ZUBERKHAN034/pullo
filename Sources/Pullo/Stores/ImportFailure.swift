import Foundation

struct ImportFailure: Equatable {
    enum Reason: Equatable {
        case notLoggedIn
        case ghTimedOut
        case rejected
        case offline
        case unreachable
        case other(String)
    }

    let user: String
    let reason: Reason

    init(user: String, reason: Reason) {
        self.user = user
        self.reason = reason
    }

    init(user: String, error: Error) {
        self.user = user
        switch error as? GitHubError {
        case .noToken: reason = .notLoggedIn
        case .ghTimedOut: reason = .ghTimedOut
        case .unauthorized: reason = .rejected
        case .offline: reason = .offline
        case .timedOut, .server: reason = .unreachable
        default: reason = .other(error.localizedDescription)
        }
    }
}
