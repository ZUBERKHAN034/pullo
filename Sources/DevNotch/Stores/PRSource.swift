import Foundation

/// Where an account's open PRs come from.
protocol PRSource: Sendable {
    func snapshot(for account: Account) async throws -> Snapshot
}

/// The real thing: GitHub's API, with the token the GitHub CLI hands out.
struct GitHubSource: PRSource {
    let accounts: AccountStore

    func snapshot(for account: Account) async throws -> Snapshot {
        let token = try await accounts.token(for: account)
        return try await GitHubClient(token: token).fetchSnapshot(account: account.login)
    }
}
