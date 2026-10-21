import Foundation

struct GitHubSource: PRSource {
    let tokens: TokenProvider

    func snapshot(for account: Account) async throws -> Snapshot {
        try await withClient(for: account) { try await $0.fetchSnapshot(account: account.login, filters: account.filters) }
    }

    func outcomes(of ids: [String], for account: Account) async throws -> [PROutcome] {
        try await withClient(for: account) { try await $0.fetchOutcomes(ids: ids) }
    }

    private func withClient<T>(for account: Account, _ request: (GitHubClient) async throws -> T) async throws -> T {
        let client = try await GitHubClient(token: tokens.token(for: account.login))
        do {
            return try await request(client)
        } catch GitHubError.unauthorized {
            await tokens.forget(account.login)
            throw GitHubError.unauthorized
        }
    }
}
