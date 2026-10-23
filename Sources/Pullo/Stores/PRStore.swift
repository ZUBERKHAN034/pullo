import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class PRStore {
    private(set) var snapshots: [String: Snapshot] = [:] {
        didSet { revision &+= 1 }
    }

    private(set) var revision = 0
    private(set) var lastUpdated: Date?
    private(set) var errors: [String: RefreshProblem] = [:]
    private(set) var updatedAt: [String: Date] = [:]
    private(set) var isLoading = false

    @ObservationIgnored var onEvents: (([PREvent]) -> Void)?

    private let accounts: AccountStore
    private let tracker: ReadTracker
    private let source: PRSource
    private let now: () -> Date
    @ObservationIgnored let poller: Poller
    @ObservationIgnored private(set) var gate: PollGate
    @ObservationIgnored private let queue = RefreshQueue()
    @ObservationIgnored private var reviewRequestsSeen: [String: Date] = [:]

    init(
        accounts: AccountStore,
        tracker: ReadTracker,
        source: PRSource,
        clock: any Clock<Duration> = ContinuousClock(),
        gate: PollGate = PollGate(),
        now: @escaping () -> Date = Date.init
    ) {
        self.accounts = accounts
        self.tracker = tracker
        self.source = source
        self.now = now
        self.gate = gate
        poller = Poller(clock: clock)
        poller.tick = { [weak self] in
            guard let self else { return .seconds(60) }
            await refresh(manual: false)
            return pollInterval
        }
        poller.onResume = { [weak self] in self?.gate.clearBackoff() }
    }

    func mine(for login: String?) -> [PullRequest] {
        login.flatMap { snapshots[$0]?.mine } ?? []
    }

    func reviewRequests(for login: String?) -> [PullRequest] {
        login.flatMap { snapshots[$0]?.reviewRequests } ?? []
    }

    func filtered(_ filter: SavedFilter.ID, for login: String?) -> [PullRequest] {
        login.flatMap { snapshots[$0]?.filtered[filter] } ?? []
    }

    func filterError(_ filter: SavedFilter.ID, for login: String?) -> String? {
        login.flatMap { snapshots[$0]?.filterErrors[filter] }
    }

    static let reviewRequestMemory: TimeInterval = 10 * 60

    var pollInterval: Duration {
        snapshots.values.contains { $0.mine.contains { $0.ci == .pending } } ? .seconds(30) : .seconds(60)
    }

    func runningCI(for logins: [String]) -> [PullRequest] {
        logins.flatMap(mine(for:))
            .filter { $0.ci == .pending && $0.checks != nil }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func start() {
        poller.start()
    }

    func refresh() async {
        await refresh(manual: true)
    }

    private func refresh(manual: Bool) async {
        if manual { gate.clearForManualRefresh() }
        await queue.run {
            isLoading = true
            await refreshAllAccounts()
            isLoading = false
        }
    }

    private func refreshAllAccounts() async {
        let everyone = accounts.accounts
        gate.prune(to: Set(everyone.map(\.login)))
        let current = everyone.filter { gate.allows($0.login, at: now()) }
        let source = source
        let tabs = Dictionary(current.map { ($0.login, accounts.filters(for: $0.login)) }) { first, _ in first }
        let results = await withTaskGroup(of: (String, Result<Snapshot, Error>).self) { group in
            for account in current {
                let filters = tabs[account.login] ?? []
                group.addTask { await Self.fetch(account, filters: filters, from: source) }
            }
            var collected: [(String, Result<Snapshot, Error>)] = []
            while let result = await group.next() { collected.append(result) }
            return collected
        }

        var events: [PREvent] = []
        for (login, result) in results where isCurrent(login) {
            switch result {
            case .success(let fetched):
                let snapshot = Snapshot(
                    mine: fetched.mine.sorted(by: Self.mineOrder),
                    reviewRequests: fetched.reviewRequests.sorted(by: Self.reviewOrder),
                    filtered: fetched.filtered,
                    filterErrors: fetched.filterErrors
                )
                var found: [PREvent] = []
                if let previous = snapshots[login] {
                    found += PREvent.diff(old: previous, new: snapshot).filter { !wasRecentlyRequested($0, login: login) }
                    found += await departures(from: previous, to: snapshot, login: login)
                }
                guard isCurrent(login) else { continue }
                events += found
                rememberReviewRequests(snapshot.reviewRequests, login: login)
                snapshots[login] = snapshot
                tracker.sync(account: login, prs: snapshot.mine + snapshot.reviewRequests)
                errors[login] = nil
                updatedAt[login] = now()
                gate.succeeded(login)
            case .failure(let error):
                let problem = RefreshProblem(error, at: now(), after: errors[login])
                Logger.store.error(
                    "Refreshing @\(login, privacy: .private(mask: .hash)) failed (\(String(describing: problem.kind), privacy: .public)): \(error.localizedDescription, privacy: .private(mask: .hash))"
                )
                errors[login] = problem
                gate.failed(login, with: error, at: now())
            }
        }

        let logins = Set(accounts.accounts.map(\.login))
        reviewRequestsSeen = reviewRequestsSeen.filter { now().timeIntervalSince($0.value) < Self.reviewRequestMemory }
        snapshots = snapshots.filter { logins.contains($0.key) }
        errors = errors.filter { logins.contains($0.key) }
        updatedAt = updatedAt.filter { logins.contains($0.key) }

        if snapshots.isEmpty {
            lastUpdated = nil
        } else if !current.isEmpty {
            lastUpdated = now()
        }

        var seen = Set<String>()
        let unique = events.filter { logins.contains($0.pr.account) && seen.insert("\($0.pr.id)|\($0.kind)").inserted }
        if !unique.isEmpty { onEvents?(unique) }
    }

    private func isCurrent(_ login: String) -> Bool {
        accounts.accounts.contains { $0.login == login }
    }

    private func wasRecentlyRequested(_ event: PREvent, login: String) -> Bool {
        guard event.kind == .reviewRequested, let seen = reviewRequestsSeen["\(login)|\(event.pr.id)"] else { return false }
        return now().timeIntervalSince(seen) < Self.reviewRequestMemory
    }

    private func rememberReviewRequests(_ prs: [PullRequest], login: String) {
        let seenAt = now()
        for pr in prs { reviewRequestsSeen["\(login)|\(pr.id)"] = seenAt }
    }

    private func departures(from old: Snapshot, to new: Snapshot, login: String) async -> [PREvent] {
        let stillThere = Set(new.mine.map(\.id))
        let gone = old.mine.filter { !stillThere.contains($0.id) }
        guard !gone.isEmpty, let account = accounts.accounts.first(where: { $0.login == login }) else { return [] }
        let outcomes: [PROutcome]
        do {
            outcomes = try await source.outcomes(of: gone.map(\.id), for: account)
        } catch {
            Logger.store.error("Looking up merged or closed PRs failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
            outcomes = []
        }
        return gone.compactMap { pr in outcomes.first { $0.id == pr.id }?.event(for: pr) }
    }

    private nonisolated static func fetch(
        _ account: Account,
        filters: [SavedFilter],
        from source: PRSource
    ) async -> (String, Result<Snapshot, Error>) {
        do {
            return try await (account.login, .success(source.snapshot(for: account, filters: filters)))
        } catch {
            return (account.login, .failure(error))
        }
    }

    private static func rank(_ pr: PullRequest) -> Int {
        if pr.isDraft { return 3 }
        if pr.needsAction { return 0 }
        if pr.isReadyToMerge { return 1 }
        return 2
    }

    static func reviewOrder(_ a: PullRequest, _ b: PullRequest) -> Bool {
        a.isDirectRequest != b.isDirectRequest ? a.isDirectRequest : a.createdAt < b.createdAt
    }

    static func mineOrder(_ a: PullRequest, _ b: PullRequest) -> Bool {
        let (ra, rb) = (rank(a), rank(b))
        return ra != rb ? ra < rb : a.updatedAt > b.updatedAt
    }
}
