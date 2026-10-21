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
    private(set) var errors: [String: String] = [:]

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
    }

    private func refresh(_ account: Account) async {
        let login = account.login
        do {
            try await discoverIfDue(account)
            errors[login] = nil
        } catch {
            Logger.store.error("Finding repos for @\(login, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            errors[login] = error.localizedDescription
            if runs[login] == nil { return }
        }
        let watched = repos[login] ?? []
        for repo in watched where isDue(repo, login: login) {
            await fetch(repo, for: account)
            publish(watched, for: login)
        }
        publish(watched, for: login)
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

    private func fetch(_ repo: String, for account: Account) async {
        let key = key(repo, account.login)
        do {
            var fetched = try await source.runs(in: repo, for: account)
            for index in fetched.indices where fetched[index].state == .running {
                fetched[index].jobs = try? await source.jobs(of: fetched[index], for: account)
            }
            byRepo[key] = fetched
        } catch {
            Logger.store.error("Loading runs of \(repo, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
        fetchedAt[key] = now()
    }

    private func key(_ repo: String, _ login: String) -> String { "\(login)|\(repo.lowercased())" }
}
