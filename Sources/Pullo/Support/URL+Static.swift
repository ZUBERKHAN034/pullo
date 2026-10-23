import Foundation

extension URL {
    init(static string: StaticString) {
        guard let url = URL(string: "\(string)") else { preconditionFailure("Invalid URL literal: \(string)") }
        self = url
    }

    static let github = URL(static: "https://github.com")

    var isWeb: Bool {
        ["http", "https"].contains(scheme?.lowercased())
    }

    static func pullRequest(repo: String, number: Int) -> URL {
        github.appending(path: "\(repo)/pull/\(number)")
    }
}
