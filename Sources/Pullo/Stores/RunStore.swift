import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class RunStore {
    static let maxRepos = 12
    static let activeInterval: TimeInterval = 10
    static let idleInterval: TimeInterval = 60
    static let discoveryInterval: TimeInterval = 300

    private(set) var runs: [String: [WorkflowRun]] = [:]
    private(set) var errors: [String: RefreshProblem] = [:]
    private(set) var jobs: [Int: [WorkflowJob]] = [:]
    private(set) var jobErrors: [Int: String] = [:]

    @ObservationIgnored var onRunsFinished: (([WorkflowRun]) -> Void)?
    @ObservationIgnored var watchedRun: Int?

    private let accounts: AccountStore
    private let prs: PRStore
    private let source: RunSource
    private let now: () -> Date
    @ObservationIgnored private var repos: [String: [String]] = [:]
    @ObservationIgnored private var discoveredAt: [String: Date] = [:]
    @ObservationIgnored private var fetchedAt: [String: Date] = [:]
    @ObservationIgnored private var byRepo: [String: [WorkflowRun]] = [:]
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var isRefreshing = false

    init(accounts: AccountStore, prs: PRStore, source: RunSource, now: @escaping () -> Date = Date.init) {
        self.accounts = accounts
        self.prs = prs
        self.source = source
        self.now = now
    }

    func isLoaded(_ login: String?) -> Bool {
        login.map { runs[$0] != nil } ?? false
    }

    func runs(for login: String?) -> [WorkflowRun] {
        login.flatMap { runs[$0] } ?? []
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(Self.activeInterval))
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let current = accounts.accounts
        for account in current {
            await refresh(account)
        }
        let logins = Set(current.map(\.login))
        runs = runs.filter { logins.contains($0.key) }
        errors = errors.filter { logins.contains($0.key) }
        let known = Set(runs.values.flatMap { $0.map(\.id) })
        if jobs.keys.contains(where: { !known.contains($0) }) { jobs = jobs.filter { known.contains($0.key) } }
    }

    private func refresh(_ account: Account) async {
        let login = account.login
        var failure: Error?
        do {
            try await discoverIfDue(account)
        } catch {
            Logger.store.error("Finding repos for @\(login, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            failure = error
            if runs[login] == nil {
                errors[login] = RefreshProblem(error, at: now(), after: errors[login])
                return
            }
        }
        let watched = repos[login] ?? []
        var succeeded = false
        for repo in watched where isDue(repo, login: login) {
            if let error = await fetch(repo, for: account) {
                failure = error
            } else {
                succeeded = true
            }
            publish(watched, for: login)
        }
        publish(watched, for: login)
        if succeeded {
            errors[login] = nil
        } else if let failure {
            errors[login] = RefreshProblem(failure, at: now(), after: errors[login])
        }
    }

    private func publish(_ watched: [String], for login: String) {
        let collected = watched.flatMap { byRepo[key($0, login)] ?? [] }.sorted { $0.createdAt > $1.createdAt }
        if runs[login] != collected { runs[login] = collected }
    }

    private func discoverIfDue(_ account: Account) async throws {
        let login = account.login
        let fromPRs = prs.mine(for: login).map(\.repo)
        if let last = discoveredAt[login], now().timeIntervalSince(last) < Self.discoveryInterval {
            let known = repos[login] ?? []
            let missing = fromPRs.filter { !known.contains($0) }
            if !missing.isEmpty { repos[login] = Self.limit(known + missing) }
            return
        }
        let pushed = try await source.pushedRepos(for: account)
        discoveredAt[login] = now()
        repos[login] = Self.limit(pushed + fromPRs)
    }

    private static func limit(_ repos: [String]) -> [String] {
        var seen = Set<String>()
        return Array(repos.filter { seen.insert($0.lowercased()).inserted }.prefix(maxRepos))
    }

    private func isDue(_ repo: String, login: String) -> Bool {
        guard let last = fetchedAt[key(repo, login)] else { return true }
        let active = byRepo[key(repo, login)]?.contains { $0.state.isActive } ?? false
        return now().timeIntervalSince(last) >= (active ? Self.activeInterval : Self.idleInterval)
    }

    @discardableResult
    private func fetch(_ repo: String, for account: Account) async -> Error? {
        let key = key(repo, account.login)
        defer { fetchedAt[key] = now() }
        do {
            var fetched = try await source.runs(in: repo, for: account)
            for index in fetched.indices where fetched[index].state == .running || fetched[index].id == watchedRun {
                guard let list = try? await source.jobs(of: fetched[index], for: account) else { continue }
                if fetched[index].state == .running { fetched[index].jobs = JobProgress(jobs: list) }
                store(list, for: fetched[index].id)
            }
            let previous = byRepo[key] ?? []
            byRepo[key] = fetched
            let finished = Self.finished(from: previous, to: fetched, login: account.login)
            if !finished.isEmpty { onRunsFinished?(finished) }
            return nil
        } catch {
            Logger.store.error("Loading runs of \(repo, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return error
        }
    }

    // MARK: - Run detail

    func loadJobs(of run: WorkflowRun) async {
        guard let account = account(for: run) else { return }
        do {
            try await store(source.jobs(of: run, for: account), for: run.id)
            jobErrors[run.id] = nil
        } catch {
            Logger.store.error("Loading jobs of run \(run.id) failed: \(error.localizedDescription, privacy: .public)")
            jobErrors[run.id] = error.localizedDescription
        }
    }

    func rerunFailedJobs(of run: WorkflowRun) async throws {
        guard let account = account(for: run) else { return }
        try await source.rerunFailedJobs(of: run, for: account)
        await refetch(run)
    }

    func cancel(_ run: WorkflowRun) async throws {
        guard let account = account(for: run) else { return }
        try await source.cancel(run, for: account)
        await refetch(run)
    }

    private func refetch(_ run: WorkflowRun) async {
        fetchedAt[key(run.repo, run.account)] = nil
        await refresh()
    }

    private func account(for run: WorkflowRun) -> Account? {
        accounts.accounts.first { $0.login == run.account }
    }

    private func store(_ list: [WorkflowJob], for run: Int) {
        if jobs[run] != list { jobs[run] = list }
    }

    private static func finished(from previous: [WorkflowRun], to current: [WorkflowRun], login: String) -> [WorkflowRun] {
        let wasActive = Set(previous.filter { $0.state.isActive }.map(\.id))
        return current.filter { run in
            wasActive.contains(run.id) && !run.state.isActive && run.pullRequest == nil && run.isStarted(by: login)
        }
    }

    private func key(_ repo: String, _ login: String) -> String { "\(login)|\(repo.lowercased())" }
}
