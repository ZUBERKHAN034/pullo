import Foundation
import Testing
@testable import DevNotch

private actor FakeSource: PRSource {
    var snapshots: [String: Snapshot]

    init(_ snapshots: [String: Snapshot]) {
        self.snapshots = snapshots
    }

    func snapshot(for account: Account) async throws -> Snapshot {
        guard let snapshot = snapshots[account.login] else { throw GitHubError.noToken }
        return snapshot
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
}
