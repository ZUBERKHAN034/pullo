import Foundation

struct GitHubSource: PRSource {
    let tokens: TokenProvider
    let sizes = QuerySizes()

    func snapshot(for account: Account, filters: [SavedFilter]) async throws -> Snapshot {
        try await withClient(for: account) { try await $0.fetchSnapshot(account: account.login, filters: filters) }
    }

    func outcomes(of ids: [String], for account: Account) async throws -> [PROutcome] {
        try await withClient(for: account) { try await $0.fetchOutcomes(ids: ids) }
    }

    private func withClient<T: Sendable>(for account: Account, _ request: @Sendable (GitHubClient) async throws -> T) async throws -> T {
        try await tokens.withToken(for: account.login) { [sizes] token in
            try await request(GitHubClient(token: token, sizes: sizes))
        }
    }
}
