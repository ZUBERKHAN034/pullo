import Foundation

struct RefreshProblem: Equatable {
    enum Kind: Equatable {
        case offline
        case unavailable
        case rateLimited
        case signIn
        case other
    }

    static let grace: TimeInterval = 90

    let kind: Kind
    let detail: String
    let since: Date

    init(_ error: Error, at now: Date, after previous: RefreshProblem? = nil) {
        detail = error.localizedDescription
        since = previous?.since ?? now
        kind = switch error as? GitHubError {
        case .offline: .offline
        case .timedOut, .queryTimedOut, .server: .unavailable
        case .rateLimited: .rateLimited
        case .unauthorized, .noToken, .ghTimedOut: .signIn
        default: .other
        }
    }

    func isWorthShowing(at now: Date) -> Bool {
        kind == .signIn || kind == .rateLimited || now.timeIntervalSince(since) >= Self.grace
    }

    var opensAccounts: Bool { kind == .signIn }

    static func first(
        in errors: [String: RefreshProblem],
        for logins: [String],
        worthShowingAt now: Date? = nil
    ) -> (login: String, problem: RefreshProblem)? {
        logins.lazy
            .compactMap { login in errors[login].map { (login: login, problem: $0) } }
            .first { found in now.map { found.problem.isWorthShowing(at: $0) } ?? true }
    }

    var symbol: String {
        switch kind {
        case .offline: "wifi.slash"
        case .unavailable: "exclamationmark.icloud"
        case .rateLimited: "hourglass"
        case .signIn: "key.slash"
        case .other: "exclamationmark.triangle"
        }
    }

    var title: String {
        switch kind {
        case .offline: String(localized: "You're offline")
        case .unavailable: String(localized: "GitHub isn't responding")
        case .rateLimited: String(localized: "GitHub's request limit was reached")
        case .signIn: String(localized: "Can't sign in to GitHub")
        case .other: String(localized: "Can't reach GitHub")
        }
    }
}
