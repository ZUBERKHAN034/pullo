import Foundation

protocol GitHubCLI: Sendable {
    var isInstalled: Bool { get }
    func users() -> [String]
    func token(for user: String) throws -> String
}
