import Foundation

actor GitHubRunSource: RunSource {
    private struct Cached<Value> {
        let etag: String
        let value: Value
    }

    private let tokens: TokenProvider
    private let session: URLSession
    private var runCache: [String: Cached<[WorkflowRun]>] = [:]
    private var jobCache: [String: Cached<[WorkflowJob]>] = [:]
    private var pushedCache: [String: Cached<[String]>] = [:]

    init(tokens: TokenProvider, session: URLSession = .github) {
        self.tokens = tokens
        self.session = session
    }

    func pushedRepos(for account: Account) async throws -> [String] {
        let login = account.login
        let cached = pushedCache[login]
        let etag = cached?.etag
        switch try await request(account, { try await $0.fetchPushedRepos(login: login, etag: etag) }) {
        case .notModified:
            return cached?.value ?? []
        case .fresh(let repos, let etag):
            pushedCache[login] = etag.map { Cached(etag: $0, value: repos) }
            return repos
        }
    }

    func runs(in repo: String, for account: Account) async throws -> [WorkflowRun] {
        let login = account.login
        let key = Self.key(login, repo)
        let cached = runCache[key]
        let etag = cached?.etag
        switch try await request(account, { try await $0.fetchRuns(in: repo, account: login, etag: etag) }) {
        case .notModified:
            return cached?.value ?? []
        case .fresh(let runs, let etag):
            runCache[key] = etag.map { Cached(etag: $0, value: runs) }
            let kept = Set(runs.map { Self.key(login, repo, run: $0.id) })
            jobCache = jobCache.filter { !$0.key.hasPrefix(key + "#") || kept.contains($0.key) }
            return runs
        }
    }

    func jobs(of run: WorkflowRun, for account: Account) async throws -> [WorkflowJob] {
        let key = Self.key(account.login, run.repo, run: run.id)
        let cached = jobCache[key]
        let etag = cached?.etag
        let repo = run.repo
        let id = run.id
        switch try await request(account, { try await $0.fetchJobs(in: repo, run: id, etag: etag) }) {
        case .notModified:
            return cached?.value ?? []
        case .fresh(let jobs, let etag):
            jobCache[key] = etag.map { Cached(etag: $0, value: jobs) }
            return jobs
        }
    }

    func rerunFailedJobs(of run: WorkflowRun, for account: Account) async throws {
        let repo = run.repo
        let id = run.id
        try await request(account) { try await $0.rerunFailedJobs(in: repo, run: id) }
    }

    func cancel(_ run: WorkflowRun, for account: Account) async throws {
        let repo = run.repo
        let id = run.id
        try await request(account) { try await $0.cancelRun(in: repo, run: id) }
    }

    func retain(_ repos: [String: [String]]) {
        let logins = Set(repos.keys)
        let keys = Set(repos.flatMap { login, list in list.map { Self.key(login, $0) } })
        pushedCache = pushedCache.filter { logins.contains($0.key) }
        runCache = runCache.filter { keys.contains($0.key) }
        jobCache = jobCache.filter { entry in entry.key.split(separator: "#").first.map { keys.contains(String($0)) } ?? false }
    }

    var cacheSizes: (runs: Int, jobs: Int, pushed: Int) {
        (runCache.count, jobCache.count, pushedCache.count)
    }

    private func request<T: Sendable>(_ account: Account, _ body: @Sendable (GitHubClient) async throws -> T) async throws -> T {
        try await tokens.withToken(for: account.login) { [session] in try await body(GitHubClient(token: $0, session: session)) }
    }

    private static func key(_ login: String, _ repo: String) -> String {
        "\(login)|\(repo.lowercased())"
    }

    private static func key(_ login: String, _ repo: String, run: Int) -> String {
        "\(key(login, repo))#\(run)"
    }
}
