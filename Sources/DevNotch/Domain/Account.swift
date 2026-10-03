import Foundation

/// A GitHub account the GitHub CLI is logged into. Its token stays in gh; DevNotch asks for it when needed.
struct Account: Identifiable, Codable, Equatable {
    let login: String
    let avatarURL: URL?

    var id: String { login }
}
