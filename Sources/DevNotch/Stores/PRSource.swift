import Foundation

protocol PRSource: Sendable {
    func snapshot(for account: Account) async throws -> Snapshot
    func outcomes(of ids: [String], for account: Account) async throws -> [PROutcome]
}

extension PRSource {
    func outcomes(of ids: [String], for account: Account) async throws -> [PROutcome] { [] }
}

struct GitHubSource: PRSource {
    let accounts: AccountStore

    func snapshot(for account: Account) async throws -> Snapshot {
        let token = try await accounts.token(for: account)
        return try await GitHubClient(token: token).fetchSnapshot(account: account.login)
    }

    func outcomes(of ids: [String], for account: Account) async throws -> [PROutcome] {
        let token = try await accounts.token(for: account)
        return try await GitHubClient(token: token).fetchOutcomes(ids: ids)
    }
}
