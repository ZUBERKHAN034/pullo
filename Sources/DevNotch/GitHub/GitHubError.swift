import Foundation

enum GitHubError: LocalizedError, Equatable {
    case noToken
    case ghTimedOut
    case unauthorized
    case http(Int)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .noToken: "gh didn't return a token for this account. Run `gh auth login`."
        case .ghTimedOut: "gh took too long to answer. Check that `gh auth status` works in Terminal."
        case .unauthorized: "GitHub rejected the gh token. Run `gh auth refresh`."
        case .http(let status): "GitHub returned error \(status)."
        case .api(let message): message
        }
    }
}
