import AppKit
@testable import Pullo
import Testing

@Suite(.serialized)
enum NotchBehavior {}

private struct StubSource: PRSource {
    let snapshots: [String: Snapshot]

    func snapshot(for account: Account, filters: [SavedFilter]) async throws -> Snapshot {
        guard var snapshot = snapshots[account.login] else { throw GitHubError.noToken }
        let all = snapshot.mine + snapshot.reviewRequests
        for filter in filters {
            snapshot.filtered[filter.id] = all.filter { filter.query.contains($0.repo) }
        }
        return snapshot
    }
}

@MainActor
final class NotchHarness {
    let clock = TestClock()
    let system = SpySystem()
    let app: AppDependencies
    var now = Date(timeIntervalSince1970: 1_000_000)
    private let scratch = ScratchDefaults()
    var defaults: UserDefaults { scratch.defaults }

    var accounts: AccountStore { app.accounts }
    var settings: AppSettings { app.settings }
    var tracker: ReadTracker { app.tracker }
    var store: PRStore { app.store }
    var runs: RunStore { app.runs }
    var toasts: ToastCenter { app.toasts }
    var list: PRListModel { app.list }
    var actions: ActionsModel { app.actions }
    var notch: NotchInteraction { app.notch }

    init(
        accounts logins: [String] = ["me"],
        mine: [PullRequest] = [],
        review: [PullRequest] = [],
        source: (any PRSource)? = nil,
        runSource: RunSource = NoRuns(),
        cli: any GitHubCLI = FakeCLI(),
        session: URLSession = .shared
    ) async {
        let defaults = scratch.defaults
        defaults.set(try? JSONEncoder().encode(logins.map { Account(login: $0, avatarURL: nil) }), for: .accounts)
        let snapshots = Dictionary(uniqueKeysWithValues: logins.map { login in
            (login, Snapshot(mine: mine.filter { $0.account == login }, reviewRequests: review.filter { $0.account == login }))
        })
        var clockNow: () -> Date = { Date() }
        app = AppDependencies(
            defaults: defaults,
            cli: cli,
            tokens: TokenProvider(cli: cli),
            session: session,
            prSource: source ?? StubSource(snapshots: snapshots),
            runSource: runSource,
            system: system,
            geometry: NotchGeometry(
                screenFrame: NSRect(x: 0, y: 0, width: 1512, height: 982),
                notchSize: CGSize(width: 185, height: 32),
                hasNotch: true
            ),
            clock: clock,
            now: { clockNow() }
        )
        clockNow = { [weak self] in self?.now ?? Date() }
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
