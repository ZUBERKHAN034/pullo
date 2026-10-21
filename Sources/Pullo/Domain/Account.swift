import Foundation

struct Account: Identifiable, Codable, Equatable {
    let login: String
    let avatarURL: URL?

    var id: String { login }
}
