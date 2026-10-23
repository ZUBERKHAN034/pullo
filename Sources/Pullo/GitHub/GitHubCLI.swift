import Foundation

protocol GitHubCLI: Sendable {
    func isInstalled() async -> Bool
    func users() async -> [String]
    func token(for user: String) async throws -> String
    func recheck() async
}

extension GitHubCLI {
    func recheck() async {}
}
