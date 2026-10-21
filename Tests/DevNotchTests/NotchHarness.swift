import AppKit
@testable import DevNotch
import Testing

@Suite(.serialized)
enum NotchBehavior {}

private struct StubSource: PRSource {
    let snapshots: [String: Snapshot]

    func snapshot(for account: Account) async throws -> Snapshot {
        guard var snapshot = snapshots[account.login] else { throw GitHubError.noToken }
        let all = snapshot.mine + snapshot.reviewRequests
        for filter in account.filters {
            snapshot.filtered[filter.id] = all.filter { filter.query.contains($0.repo) }
        }
        return snapshot
    }
}

@MainActor
final class NotchHarness {
    let clock = TestClock()
    let system = SpySystem()
    let accounts: AccountStore
    let settings: AppSettings
    let tracker: ReadTracker
    let store: PRStore
    let list: PRListModel
    let notch: NotchInteraction
    let runs: RunStore
    let actions: ActionsModel
    var now = Date(timeIntervalSince1970: 1_000_000)
    private let scratch = ScratchDefaults()
    var defaults: UserDefaults { scratch.defaults }

    init(
        accounts logins: [String] = ["me"],
        mine: [PullRequest] = [],
        review: [PullRequest] = [],
        runSource: RunSource = NoRuns()
    ) async {
        let defaults = scratch.defaults
        defaults.set(try? JSONEncoder().encode(logins.map { Account(login: $0, avatarURL: nil) }), for: .accounts)
        accounts = AccountStore(defaults: defaults)
        settings = AppSettings(defaults: defaults)
        tracker = ReadTracker(defaults: defaults)
        let snapshots = Dictionary(uniqueKeysWithValues: logins.map { login in
            (login, Snapshot(mine: mine.filter { $0.account == login }, reviewRequests: review.filter { $0.account == login }))
        })
        store = PRStore(accounts: accounts, tracker: tracker, source: StubSource(snapshots: snapshots))
        list = PRListModel(store: store, accounts: accounts, tracker: tracker, system: system, clock: clock)
        var clockNow: () -> Date = { Date() }
        runs = RunStore(accounts: accounts, prs: store, source: runSource) { clockNow() }
        actions = ActionsModel(store: runs, list: list)
        notch = NotchInteraction(
            list: list,
            runs: runs,
            accounts: accounts,
            settings: settings,
            system: system,
            geometry: NotchGeometry(
                screenFrame: NSRect(x: 0, y: 0, width: 1512, height: 982),
                notchSize: CGSize(width: 185, height: 32),
                hasNotch: true
            ),
            clock: clock
        )
        clockNow = { [unowned self] in now }
        runs.onRunsFinished = { [unowned notch] in notch.runsFinished($0) }
        notch.actions = actions
        await store.refresh()
    }

    func inside(_ state: NotchState) -> NSPoint {
        let rect = notch.layout.hitRect(for: state)
        return NSPoint(x: rect.midX, y: rect.midY)
    }

    let outside = NSPoint(x: 10, y: 10)

    func alert(_ headline: String = "CI passed", priority: Int = 0) -> NotchAlert {
        NotchAlert(symbol: "checkmark", tint: .green, headline: headline, detail: "", priority: priority)
    }
}
