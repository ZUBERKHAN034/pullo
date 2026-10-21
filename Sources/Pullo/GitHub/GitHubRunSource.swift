import Foundation

actor GitHubRunSource: RunSource {
    private struct Cached<Value> {
        let etag: String
        let value: Value
    }

    private let tokens: TokenProvider
    private var runCache: [String: Cached<[WorkflowRun]>] = [:]
    private var jobCache: [String: Cached<[WorkflowJob]>] = [:]

    init(tokens: TokenProvider) {
        self.tokens = tokens
    }

    func pushedRepos(for account: Account) async throws -> [String] {
        try await client(for: account).fetchPushedRepos(login: account.login)
    }

    func runs(in repo: String, for account: Account) async throws -> [WorkflowRun] {
        let key = "\(account.login)|\(repo)"
        let cached = runCache[key]
        switch try await client(for: account).fetchRuns(in: repo, account: account.login, etag: cached?.etag) {
        case .notModified:
            return cached?.value ?? []
        case .fresh(let runs, let etag):
            runCache[key] = etag.map { Cached(etag: $0, value: runs) }
            return runs
        }
    }

    func jobs(of run: WorkflowRun, for account: Account) async throws -> [WorkflowJob] {
        let key = "\(account.login)|\(run.id)"
        let cached = jobCache[key]
        switch try await client(for: account).fetchJobs(in: run.repo, run: run.id, etag: cached?.etag) {
        case .notModified:
            return cached?.value ?? []
        case .fresh(let jobs, let etag):
            jobCache[key] = etag.map { Cached(etag: $0, value: jobs) }
            return jobs
        }
    }

    func rerunFailedJobs(of run: WorkflowRun, for account: Account) async throws {
        try await client(for: account).rerunFailedJobs(in: run.repo, run: run.id)
    }

    func cancel(_ run: WorkflowRun, for account: Account) async throws {
        try await client(for: account).cancelRun(in: run.repo, run: run.id)
    }

    private func client(for account: Account) async throws -> GitHubClient {
        try await GitHubClient(token: tokens.token(for: account.login))
    }
}
