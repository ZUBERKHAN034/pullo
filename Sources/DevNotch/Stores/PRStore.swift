import Foundation
import Combine

@MainActor
final class PRStore: ObservableObject {
    /// Each account's PRs, kept apart and already sorted.
    @Published private(set) var snapshots: [String: Snapshot] = [:]
    @Published private(set) var lastUpdated: Date?
    /// Last error per account login; an account that failed keeps showing its previous PRs.
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var isLoading = false

    /// Called once per refresh with everything that changed, so alerts can be grouped.
    var onEvents: (([PREvent]) -> Void)?

    private let accounts: AccountStore
    private let tracker: ReadTracker
    private let source: PRSource
    private var pollTask: Task<Void, Never>?
    private var refreshQueued = false
    private var cancellables = Set<AnyCancellable>()
    private let interval: Duration = .seconds(60)

    init(accounts: AccountStore, tracker: ReadTracker, source: PRSource) {
        self.accounts = accounts
        self.tracker = tracker
        self.source = source
        accounts.$accounts
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)
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
        // A refresh requested mid-flight (e.g. an account was just added) runs right after, not never.
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
        let source = self.source
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
                if let previous = snapshots[login] { events += PREvent.diff(old: previous, new: snapshot) }
                snapshots[login] = snapshot
                tracker.sync(account: login, prs: snapshot.mine + snapshot.reviewRequests)
                errors[login] = nil
            case .failure(let error):
                if error as? GitHubError == .unauthorized { accounts.invalidateToken(for: login) }
                errors[login] = error.localizedDescription
            }
        }

        let logins = Set(current.map(\.login))
        snapshots = snapshots.filter { logins.contains($0.key) }
        errors = errors.filter { logins.contains($0.key) }

        lastUpdated = snapshots.isEmpty ? nil : Date()

        // Two accounts can see the same PR; alert once.
        var seen = Set<String>()
        let unique = events.filter { seen.insert("\($0.pr.id)|\($0.kind)").inserted }
        if !unique.isEmpty { onEvents?(unique) }
    }

    /// Kept out of the task group's closure: the Swift 6.4 optimizer dropped every result when the call was inline.
    private nonisolated static func fetch(_ account: Account, from source: PRSource) async -> (String, Result<Snapshot, Error>) {
        do {
            return (account.login, .success(try await source.snapshot(for: account)))
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
