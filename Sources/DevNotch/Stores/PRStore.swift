import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class PRStore {
    private(set) var snapshots: [String: Snapshot] = [:]
    private(set) var lastUpdated: Date?
    private(set) var errors: [String: String] = [:]
    private(set) var isLoading = false

    @ObservationIgnored var onEvents: (([PREvent]) -> Void)?

    private let accounts: AccountStore
    private let tracker: ReadTracker
    private let source: PRSource
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var refreshQueued = false
    private let interval: Duration = .seconds(60)

    init(accounts: AccountStore, tracker: ReadTracker, source: PRSource) {
        self.accounts = accounts
        self.tracker = tracker
        self.source = source
    }

    func mine(for login: String?) -> [PullRequest] {
        login.flatMap { snapshots[$0]?.mine } ?? []
    }

    func reviewRequests(for login: String?) -> [PullRequest] {
        login.flatMap { snapshots[$0]?.reviewRequests } ?? []
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: self?.interval ?? .seconds(60))
            }
        }
    }

    func refresh() async {
        guard !isLoading else {
            refreshQueued = true
            return
        }
        isLoading = true
        defer { isLoading = false }
        repeat {
            refreshQueued = false
            await refreshAllAccounts()
        } while refreshQueued
    }

    private func refreshAllAccounts() async {
        let current = accounts.accounts
        let source = source
        let results = await withTaskGroup(of: (String, Result<Snapshot, Error>).self) { group in
            for account in current {
                group.addTask { await Self.fetch(account, from: source) }
            }
            var collected: [(String, Result<Snapshot, Error>)] = []
            while let result = await group.next() { collected.append(result) }
            return collected
        }

        var events: [PREvent] = []
        for (login, result) in results {
            switch result {
            case .success(let fetched):
                let snapshot = Snapshot(
                    mine: fetched.mine.sorted(by: Self.mineOrder),
                    reviewRequests: fetched.reviewRequests.sorted(by: Self.reviewOrder)
                )
                if let previous = snapshots[login] {
                    events += PREvent.diff(old: previous, new: snapshot)
                    events += await departures(from: previous, to: snapshot, login: login)
                }
                snapshots[login] = snapshot
                tracker.sync(account: login, prs: snapshot.mine + snapshot.reviewRequests)
                errors[login] = nil
            case .failure(let error):
                Logger.store.error("Refreshing @\(login, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                errors[login] = error.localizedDescription
            }
        }

        let logins = Set(current.map(\.login))
        snapshots = snapshots.filter { logins.contains($0.key) }
        errors = errors.filter { logins.contains($0.key) }

        lastUpdated = snapshots.isEmpty ? nil : Date()

        var seen = Set<String>()
        let unique = events.filter { seen.insert("\($0.pr.id)|\($0.kind)").inserted }
        if !unique.isEmpty { onEvents?(unique) }
    }

    private func departures(from old: Snapshot, to new: Snapshot, login: String) async -> [PREvent] {
        let stillThere = Set(new.mine.map(\.id))
        let gone = old.mine.filter { !stillThere.contains($0.id) }
        guard !gone.isEmpty, let account = accounts.accounts.first(where: { $0.login == login }) else { return [] }
        let outcomes: [PROutcome]
        do {
            outcomes = try await source.outcomes(of: gone.map(\.id), for: account)
        } catch {
            Logger.store.error("Looking up merged or closed PRs failed: \(error.localizedDescription, privacy: .public)")
            outcomes = []
        }
        return gone.compactMap { pr in outcomes.first { $0.id == pr.id }?.event(for: pr) }
    }

    private nonisolated static func fetch(_ account: Account, from source: PRSource) async -> (String, Result<Snapshot, Error>) {
        do {
            return try await (account.login, .success(source.snapshot(for: account)))
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

    private static func reviewOrder(_ a: PullRequest, _ b: PullRequest) -> Bool {
        a.isDirectRequest != b.isDirectRequest ? a.isDirectRequest : a.createdAt < b.createdAt
    }

    private static func mineOrder(_ a: PullRequest, _ b: PullRequest) -> Bool {
        let (ra, rb) = (rank(a), rank(b))
        return ra != rb ? ra < rb : a.updatedAt > b.updatedAt
    }
}
