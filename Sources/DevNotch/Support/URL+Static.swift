import Foundation

extension URL {
    /// For addresses written in the code, where a typo is a bug to catch in development rather than a case to handle.
    init(static string: StaticString) {
        guard let url = URL(string: "\(string)") else { preconditionFailure("Invalid URL literal: \(string)") }
        self = url
    }

    static let github = URL(static: "https://github.com")

    static func pullRequest(repo: String, number: Int) -> URL {
        github.appending(path: "\(repo)/pull/\(number)")
    }
}
