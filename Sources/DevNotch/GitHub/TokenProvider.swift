import Foundation

actor TokenProvider {
    private let cli: any GitHubCLI
    private var tokens: [String: String] = [:]

    init(cli: any GitHubCLI) {
        self.cli = cli
    }

    func token(for login: String) throws -> String {
        if let cached = tokens[login] { return cached }
        let token = try cli.token(for: login)
        tokens[login] = token
        return token
    }

    func remember(_ token: String, for login: String) {
        tokens[login] = token
    }

    func forget(_ login: String) {
        tokens[login] = nil
    }
}
