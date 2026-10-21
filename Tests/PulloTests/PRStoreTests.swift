import Foundation
@testable import Pullo
import Testing

private actor FakeSource: PRSource {
    var snapshots: [String: Snapshot]
    var outcomes: [PROutcome] = []
    var failures: [String: GitHubError] = [:]

    init(_ snapshots: [String: Snapshot]) {
        self.snapshots = snapshots
    }

    func set(_ login: String, _ snapshot: Snapshot) { snapshots[login] = snapshot }
    func set(outcomes: [PROutcome]) { self.outcomes = outcomes }
    func fail(_ login: String, with error: GitHubError?) { failures[login] = error }

    func snapshot(for account: Account, filters: [SavedFilter]) async throws -> Snapshot {
        if let failure = failures[account.login] { throw failure }
        guard let snapshot = snapshots[account.login] else { throw GitHubError.noToken }
        return snapshot
    }

    func outcomes(of ids: [String], for account: Account) async throws -> [PROutcome] {
        outcomes.filter { ids.contains($0.id) }
    }
}

@MainActor
struct PRStoreTests {
    private let scratch = ScratchDefaults()

    private func makeDefaults(accounts: [String]) -> UserDefaults {
        let defaults = scratch.defaults
        let list = accounts.map { Account(login: $0, avatarURL: nil) }
        defaults.set(try? JSONEncoder().encode(list), for: .accounts)
        return defaults
    }

    @Test func loadsEveryAccountFromTheSource() async {
        let defaults = makeDefaults(accounts: ["work", "home"])
        let source = FakeSource([
            "work": Snapshot(mine: [.make(id: "PR_1", account: "work")], reviewRequests: []),
            "home": Snapshot(mine: [], reviewRequests: [.make(id: "PR_2", account: "home")]),
        ])
        let store = PRStore(accounts: AccountStore(defaults: defaults), tracker: ReadTracker(defaults: defaults), source: source)
        await store.refresh()
        #expect(store.mine(for: "work").map(\.id) == ["PR_1"])
        #expect(store.reviewRequests(for: "home").map(\.id) == ["PR_2"])
        #expect(store.errors.isEmpty)
    }

    @Test func pollsFasterWhileChecksRun() async {
        let defaults = makeDefaults(accounts: ["work"])
        let source = FakeSource(["work": Snapshot(mine: [.make(id: "PR_1", account: "work")], reviewRequests: [])])
        let store = PRStore(accounts: AccountStore(defaults: defaults), tracker: ReadTracker(defaults: defaults), source: source)
        await store.refresh()
        #expect(store.pollInterval == .seconds(60))
        await source.set("work", Snapshot(mine: [.make(id: "PR_1", account: "work", ci: .pending)], reviewRequests: []))
        await store.refresh()
        #expect(store.pollInterval == .seconds(30))
    }

    @Test func anAccountThatFailsKeepsItsError() async {
        let defaults = makeDefaults(accounts: ["work", "gone"])
        let source = FakeSource(["work": Snapshot(mine: [], reviewRequests: [])])
        let store = PRStore(accounts: AccountStore(defaults: defaults), tracker: ReadTracker(defaults: defaults), source: source)
        await store.refresh()
        #expect(store.snapshots["work"] != nil)
        #expect(store.errors["gone"] != nil)
    }

    @Test func aHiccupStaysQuietUntilItLasts() async {
        let defaults = makeDefaults(accounts: ["me"])
        let source = FakeSource(["me": Snapshot(mine: [], reviewRequests: [])])
        var now = Date(timeIntervalSince1970: 1000)
        let store = PRStore(accounts: AccountStore(defaults: defaults), tracker: ReadTracker(defaults: defaults), source: source) { now }
        await store.refresh()
        await source.fail("me", with: .server(502))
        now += 60
        await store.refresh()
        #expect(store.errors["me"]?.kind == .unavailable)
        #expect(store.errors["me"]?.isWorthShowing(at: now) == false)
        now += 60
        await store.refresh()
        #expect(store.errors["me"]?.isWorthShowing(at: now) == false)
        now += 40
        await store.refresh()
        #expect(store.errors["me"]?.isWorthShowing(at: now) == true)
        #expect(store.updatedAt["me"] == Date(timeIntervalSince1970: 1000))
        #expect(store.snapshots["me"] != nil)
        await source.fail("me", with: nil)
        await store.refresh()
        #expect(store.errors["me"] == nil)
    }

    @Test func signInProblemsShowRightAway() async {
        let defaults = makeDefaults(accounts: ["me"])
        let source = FakeSource(["me": Snapshot(mine: [], reviewRequests: [])])
        let store = PRStore(accounts: AccountStore(defaults: defaults), tracker: ReadTracker(defaults: defaults), source: source)
        await source.fail("me", with: .unauthorized)
        await store.refresh()
        #expect(store.errors["me"]?.opensAccounts == true)
        #expect(store.errors["me"]?.isWorthShowing(at: .now) == true)
    }

    @Test func aPRThatLeavesTheListAlertsWhetherItWasMergedOrClosed() async {
        let defaults = makeDefaults(accounts: ["me"])
        let merged = PullRequest.make(id: "PR_1", account: "me")
        let closed = PullRequest.make(id: "PR_2", account: "me")
        let fellOff = PullRequest.make(id: "PR_3", account: "me")
        let source = FakeSource(["me": Snapshot(mine: [merged, closed, fellOff], reviewRequests: [])])
        let store = PRStore(accounts: AccountStore(defaults: defaults), tracker: ReadTracker(defaults: defaults), source: source)
        var events: [PREvent] = []
        store.onEvents = { events += $0 }
        await store.refresh()

        await source.set("me", Snapshot(mine: [], reviewRequests: []))
        await source.set(outcomes: [
            PROutcome(id: "PR_1", state: .merged, actor: "ana", actorAvatar: nil),
            PROutcome(id: "PR_2", state: .closed, actor: "teo", actorAvatar: nil),
            PROutcome(id: "PR_3", state: .stillOpen, actor: nil, actorAvatar: nil),
        ])
        await store.refresh()
        #expect(events.map(\.kind) == [.merged, .closed])
        #expect(events.map(\.actor) == ["ana", "teo"])
    }
}
