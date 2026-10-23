import Foundation

extension ImportFailure {
    enum Recovery: Equatable {
        case copy(String)
        case retry
    }

    static let loginCommand = "gh auth login"

    var message: String {
        switch reason {
        case .notLoggedIn: String(localized: "gh isn't logged into @\(user) anymore. Log in again in Terminal, then add it.")
        case .ghTimedOut: String(localized: "gh took too long to answer for @\(user).")
        case .rejected: String(localized: "GitHub rejected the gh login for @\(user). Log in again in Terminal, then add it.")
        case .offline: String(localized: "Couldn't reach GitHub. Check your internet connection.")
        case .unreachable: String(localized: "GitHub isn't answering right now. Try again in a moment.")
        case .other(let detail): String(localized: "Couldn't add @\(user): \(detail)")
        }
    }

    var recovery: Recovery {
        switch reason {
        case .notLoggedIn, .rejected: .copy(Self.loginCommand)
        default: .retry
        }
    }

    var recoveryTitle: String {
        switch recovery {
        case .copy: String(localized: "Copy command")
        case .retry: String(localized: "Try again")
        }
    }
}
