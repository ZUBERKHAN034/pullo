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
    static let closedActiveInterval: TimeInterval = 30
    static let closedIdleInterval: TimeInterval = 300
    static let parkingTime: TimeInterval = 3 * 60 * 60

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
    @ObservationIgnored let poller: Poller
    @ObservationIgnored private(set) var gate: PollGate
    @ObservationIgnored private(set) var isPanelOpen = true
    @ObservationIgnored private var repos: [String: [String]] = [:]
    @ObservationIgnored private var discoveredAt: [String: Date] = [:]
    @ObservationIgnored private var fetchedAt: [String: Date] = [:]
    @ObservationIgnored private var parkedUntil: [String: Date] = [:]
    @ObservationIgnored private var byRepo: [String: [WorkflowRun]] = [:]
    @ObservationIgnored private var isRefreshing = false

    init(
        accounts: AccountStore,
        prs: PRStore,
        source: RunSource,
        clock: any Clock<Duration> = ContinuousClock(),
        gate: PollGate = PollGate(),
        now: @escaping () -> Date = Date.init
    ) {
        self.accounts = accounts
        self.prs = prs
        self.source = source
        self.now = now
        self.gate = gate
        poller = Poller(clock: clock)
        poller.tick = { [weak self] in
            guard let self else { return .seconds(Self.activeInterval) }
            await refresh(manual: false)
            return .seconds(isPanelOpen ? Self.activeInterval : Self.closedActiveInterval)
        }
        poller.onResume = { [weak self] in self?.gate.clearBackoff() }
    }

    func isLoaded(_ login: String?) -> Bool {
        login.map { runs[$0] != nil } ?? false
    }

    func runs(for login: String?) -> [WorkflowRun] {
        login.flatMap { runs[$0] } ?? []
    }

    func start() {
        poller.start()
    }

    func setPanelOpen(_ open: Bool) {
        guard isPanelOpen != open else { return }
        isPanelOpen = open
        if open { poller.pollNow() }
    }

    func refresh() async {
        await refresh(manual: true)
    }

    private func refresh(manual: Bool) async {
        if manual { gate.clearForManualRefresh() }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let current = accounts.accounts
        gate.prune(to: Set(current.map(\.login)))
        for account in current where gate.allows(account.login, at: now()) {
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
            Logger.store.error(
                "Finding repos for @\(login, privacy: .private(mask: .hash)) failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
            failure = error
            if runs[login] == nil || Self.stopsAccount(error) {
                errors[login] = RefreshProblem(error, at: now(), after: errors[login])
                gate.failed(login, with: error, at: now())
                return
            }
        }
        let watched = repos[login] ?? []
        var succeeded = false
        for repo in watched where isDue(repo, login: login) {
            if let error = await fetch(repo, for: account) {
                if (error as? GitHubError)?.isForbidden == true { continue }
                failure = error
                if Self.stopsAccount(error) { break }
            } else {
                succeeded = true
            }
            publish(watched, for: login)
        }
        publish(watched, for: login)
        if succeeded {
            errors[login] = nil
            gate.succeeded(login)
        } else if let failure {
            errors[login] = RefreshProblem(failure, at: now(), after: errors[login])
            gate.failed(login, with: failure, at: now())
        }
    }

    private static func stopsAccount(_ error: Error) -> Bool {
        switch error as? GitHubError {
        case .offline?, .rateLimited?, .unauthorized?, .noToken?, .ghTimedOut?: true
        default: false
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
            if !missing.isEmpty { repos[login] = limit(known + missing, for: login) }
            return
        }
        let pushed = try await source.pushedRepos(for: account)
        discoveredAt[login] = now()
        repos[login] = limit(pushed + fromPRs, for: login)
    }

    private func limit(_ repos: [String], for login: String) -> [String] {
        var seen = Set<String>()
        return Array(repos.filter { !isParked($0, login: login) && seen.insert($0.lowercased()).inserted }.prefix(Self.maxRepos))
    }

    private func isParked(_ repo: String, login: String) -> Bool {
        parkedUntil[key(repo, login)].map { now() < $0 } ?? false
    }

    private func isDue(_ repo: String, login: String) -> Bool {
        guard !isParked(repo, login: login) else { return false }
        guard let last = fetchedAt[key(repo, login)] else { return true }
        let list = byRepo[key(repo, login)] ?? []
        let interval = if isPanelOpen {
            list.contains { $0.state.isActive } ? Self.activeInterval : Self.idleInterval
        } else {
            list.contains { $0.state.isActive && $0.isStarted(by: login) } ? Self.closedActiveInterval : Self.closedIdleInterval
        }
        return now().timeIntervalSince(last) >= interval
    }

    private func needsJobs(_ run: WorkflowRun, login: String) -> Bool {
        if run.id == watchedRun { return true }
        guard run.state == .running else { return false }
        return isPanelOpen || run.isStarted(by: login)
    }

    @discardableResult
    private func fetch(_ repo: String, for account: Account) async -> Error? {
        let key = key(repo, account.login)
        defer { fetchedAt[key] = now() }
        do {
            var fetched = try await source.runs(in: repo, for: account)
            for index in fetched.indices where needsJobs(fetched[index], login: account.login) {
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
            Logger.store.error(
                "Loading runs of \(repo, privacy: .private(mask: .hash)) failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
            if (error as? GitHubError)?.isForbidden == true {
                parkedUntil[key] = now().addingTimeInterval(Self.parkingTime)
                repos[account.login]?.removeAll { $0.caseInsensitiveCompare(repo) == .orderedSame }
            }
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
            Logger.store
                .error(
                    "Loading jobs of run \(run.id, privacy: .public) failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
                )
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
