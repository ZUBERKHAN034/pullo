import Foundation

enum GitHubError: LocalizedError, Equatable {
    case noToken
    case ghTimedOut
    case unauthorized
    case offline
    case timedOut
    case server(Int)
    case rateLimited(until: Date?)
    case http(Int)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .noToken: String(localized: "gh didn't return a token for this account. Run `gh auth login`.")
        case .ghTimedOut: String(localized: "gh took too long to answer. Check that `gh auth status` works in Terminal.")
        case .unauthorized: String(localized: "GitHub rejected the gh token. Run `gh auth refresh`.")
        case .offline: String(localized: "Your Mac isn't connected to the internet.")
        case .timedOut: String(localized: "GitHub took too long to answer.")
        case .server(let status): String(localized: "GitHub is having trouble right now (error \(status)).")
        case .rateLimited(let until):
            if let until {
                String(
                    localized: "GitHub's request limit for this account was reached. It resets at \(until.formatted(date: .omitted, time: .shortened))."
                )
            } else {
                String(localized: "GitHub's request limit for this account was reached. Pullo tries again in a few minutes.")
            }
        case .http(let status): String(localized: "GitHub returned error \(status).")
        case .api(let message): message
        }
    }

    var isTransient: Bool {
        switch self {
        case .offline, .timedOut, .server: true
        default: false
        }
    }

    var isOverloaded: Bool {
        switch self {
        case .timedOut, .server: true
        default: false
        }
    }

    init?(_ error: URLError) {
        switch error.code {
        case .timedOut:
            self = .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            self = .offline
        default:
            return nil
        }
    }
}
