import Foundation
@testable import Pullo
import Testing

actor ChangingSource: PRSource {
    private var snapshots: [String: Snapshot] = [:]
    private(set) var requests: [String] = []

    func set(_ login: String, _ snapshot: Snapshot) { snapshots[login] = snapshot }

    func snapshot(for account: Account, filters: [SavedFilter]) async throws -> Snapshot {
        requests.append(account.login)
        return snapshots[account.login] ?? Snapshot(mine: [], reviewRequests: [])
    }
}

extension NotchBehavior {
    @MainActor
    struct AppWiringTests {
        @Test func aPREventShowsAPeek() async {
            let source = ChangingSource()
            let h = await NotchHarness(source: source)
            await source.set("me", Snapshot(mine: [], reviewRequests: [.make(id: "PR_7", author: "ana")]))
            await h.store.refresh()
            #expect(h.notch.state == .peek)
            #expect(h.notch.peekAlert?.pr?.id == "PR_7")
        }

        @Test func removingAnAccountForgetsItsReadStateAndMute() async throws {
            let h = await NotchHarness(accounts: ["me", "work"], mine: [.make(id: "PR_1", account: "work")])
            h.settings.mutedAccounts.insert("work")
            #expect(h.tracker.baselines.keys.contains { $0.hasPrefix("work|") })
            try h.accounts.remove(#require(h.accounts.accounts.last))
            #expect(!h.tracker.baselines.keys.contains { $0.hasPrefix("work|") })
            #expect(!h.settings.mutedAccounts.contains("work"))
        }

        @Test func addingAnAccountRefreshesBothStores() async {
            let cli = LoginCLI()
            cli.logins = ["ana"]
            let token = UUID().uuidString
            cli.token = token
            let session = StubURLProtocol.session(
                token: token,
                responses: [.init(status: 200, body: #"{ "login": "ana", "avatar_url": null }"#)]
            )
            let source = ChangingSource()
            let runs = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [.make(id: 1)]])
            let h = await NotchHarness(source: source, runSource: runs, cli: cli, session: session)
            await h.accounts.importFromGH("ana")
            await eventually { h.store.snapshots["ana"] != nil && h.runs.isLoaded("ana") }
            #expect(h.store.snapshots["ana"] != nil)
            #expect(h.runs.isLoaded("ana"))
            #expect(h.system.focusRequests == 1)
        }

        @Test func removingAnAccountRefreshesThePRsOnce() async throws {
            let source = ChangingSource()
            let h = await NotchHarness(accounts: ["me", "work"], source: source)
            let workAPI = SavedFilter(name: "API", query: "repo:acme/api", account: "work")
            h.accounts.setTabs(h.accounts.tabs + [workAPI])
            await eventually { await source.requests.count == 4 }
            try h.accounts.remove(#require(h.accounts.accounts.last))
            await eventually { await source.requests.count > 4 }
            await h.clock.settle()
            #expect(await source.requests.count == 5)
        }
    }
}
