import Foundation
import Testing
@testable import DevNotch

private actor FakeSource: PRSource {
    var snapshots: [String: Snapshot]
    var outcomes: [PROutcome] = []

    init(_ snapshots: [String: Snapshot]) {
        self.snapshots = snapshots
    }

    func set(_ login: String, _ snapshot: Snapshot) { snapshots[login] = snapshot }
    func set(outcomes: [PROutcome]) { self.outcomes = outcomes }

    func snapshot(for account: Account) async throws -> Snapshot {
        guard let snapshot = snapshots[account.login] else { throw GitHubError.noToken }
        return snapshot
    }

    func outcomes(of ids: [String], for account: Account) async throws -> [PROutcome] {
        outcomes.filter { ids.contains($0.id) }
    }
}

@MainActor
struct PRStoreTests {
    private func makeDefaults(accounts: [String]) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "DevNotchTests.\(UUID().uuidString)")!
        let list = accounts.map { Account(login: $0, avatarURL: nil) }
        defaults.set(try? JSONEncoder().encode(list), forKey: "accounts")
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

    @Test func anAccountThatFailsKeepsItsError() async {
        let defaults = makeDefaults(accounts: ["work", "gone"])
        let source = FakeSource(["work": Snapshot(mine: [], reviewRequests: [])])
        let store = PRStore(accounts: AccountStore(defaults: defaults), tracker: ReadTracker(defaults: defaults), source: source)
        await store.refresh()
        #expect(store.snapshots["work"] != nil)
        #expect(store.errors["gone"] != nil)
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
