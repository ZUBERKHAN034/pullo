import Foundation
@testable import Pullo
import Testing

actor Hold {
    private var held = false
    private var arrived = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func close() { held = true }

    func open() {
        held = false
        let resumed = waiting
        waiting = []
        for continuation in resumed { continuation.resume() }
    }

    func pass() async {
        arrived += 1
        guard held else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func arrivals() -> Int { arrived }

    func waitForArrivals(_ count: Int) async {
        for _ in 0..<500 where arrived < count {
            try? await Task.sleep(for: .milliseconds(2))
        }
    }
}

private actor HeldSource: PRSource {
    let hold = Hold()
    private var snapshots: [String: Snapshot]

    init(_ snapshots: [String: Snapshot]) {
        self.snapshots = snapshots
    }

    func set(_ login: String, _ snapshot: Snapshot) { snapshots[login] = snapshot }

    func snapshot(for account: Account, filters: [SavedFilter]) async throws -> Snapshot {
        await hold.pass()
        guard let snapshot = snapshots[account.login] else { throw GitHubError.noToken }
        return snapshot
    }
}

private actor HeldRunSource: RunSource {
    let hold = Hold()
    private let pushed: [String]
    private var byRepo: [String: [WorkflowRun]]
    private(set) var runRequests: [String] = []
    private(set) var retained: [String: [String]]?

    init(pushed: [String], runs: [String: [WorkflowRun]]) {
        self.pushed = pushed
        byRepo = runs
    }

    func set(_ runs: [WorkflowRun], in repo: String) { byRepo[repo] = runs }

    func pushedRepos(for account: Account) async throws -> [String] { pushed }

    func runs(in repo: String, for account: Account) async throws -> [WorkflowRun] {
        runRequests.append("\(account.login) \(repo)")
        let list = byRepo[repo] ?? []
        await hold.pass()
        return list.map { run in
            WorkflowRun(
                id: run.id, account: account.login, repo: run.repo, workflow: run.workflow, title: run.title, branch: run.branch,
                event: run.event, state: run.state, url: run.url, actor: account.login, triggeringActor: account.login,
                createdAt: run.createdAt, startedAt: run.startedAt, updatedAt: run.updatedAt, pullRequest: run.pullRequest
            )
        }
    }

    func jobs(of run: WorkflowRun, for account: Account) async throws -> [WorkflowJob] { [] }
    func rerunFailedJobs(of run: WorkflowRun, for account: Account) async throws {}
    func cancel(_ run: WorkflowRun, for account: Account) async throws {}
    func retain(_ repos: [String: [String]]) async { retained = repos }
}

extension NotchBehavior {
    @MainActor
    struct AccountRemovalTests {
        private let scratch = ScratchDefaults()

        private func defaults(_ logins: [String]) -> UserDefaults {
            let defaults = scratch.defaults
            defaults.set(try? JSONEncoder().encode(logins.map { Account(login: $0, avatarURL: nil) }), for: .accounts)
            return defaults
        }

        @Test func anAccountRemovedDuringARefreshStaysGone() async throws {
            let defaults = defaults(["me", "gone"])
            let source = HeldSource([
                "me": Snapshot(mine: [], reviewRequests: []),
                "gone": Snapshot(mine: [], reviewRequests: []),
            ])
            let accounts = AccountStore(defaults: defaults)
            let tracker = ReadTracker(defaults: defaults)
            let store = PRStore(accounts: accounts, tracker: tracker, source: source)
            var events: [PREvent] = []
            store.onEvents = { events += $0 }
            await store.refresh()

            await source.set("gone", Snapshot(mine: [], reviewRequests: [.make(id: "PR_9", account: "gone", author: "ana")]))
            await source.hold.close()
            let refreshing = Task { await store.refresh() }
            await source.hold.waitForArrivals(4)
            let gone = try #require(accounts.accounts.first { $0.login == "gone" })
            accounts.remove(gone)
            tracker.forget(account: "gone")
            await source.hold.open()
            await refreshing.value

            #expect(store.snapshots["gone"] == nil)
            #expect(store.snapshots["me"] != nil)
            #expect(!tracker.baselines.keys.contains { $0.hasPrefix("gone|") })
            #expect(events.isEmpty)
        }

        @Test func runsOfAnAccountRemovedDuringARefreshStayGone() async throws {
            let source = HeldRunSource(pushed: ["acme/api"], runs: ["acme/api": [.make(id: 1)]])
            let h = await NotchHarness(accounts: ["me", "gone"], runSource: source)
            await source.hold.close()
            let refreshing = Task { await h.runs.refresh() }
            await source.hold.waitForArrivals(1)
            let removed = try #require(h.accounts.accounts.first { $0.login == "me" })
            h.accounts.remove(removed)
            await source.hold.open()
            await refreshing.value
            #expect(h.runs.runs["me"] == nil)
            #expect(h.runs.runs(for: "gone").map(\.id) == [1])
            #expect(await source.retained?.keys.sorted() == ["gone"])
        }

        @Test func aRefreshAskedForDuringAnotherOneStillHappens() async throws {
            let source = HeldRunSource(pushed: ["acme/api"], runs: ["acme/api": [.make(id: 1, state: .running)]])
            let h = await NotchHarness(runSource: source)
            await h.runs.refresh()
            #expect(h.runs.runs(for: "me").first?.state == .running)

            await source.hold.close()
            h.now += RunStore.closedActiveInterval
            let first = Task { await h.runs.refresh() }
            await source.hold.waitForArrivals(2)
            await source.set([.make(id: 1, state: .cancelled)], in: "acme/api")
            let run = try #require(h.runs.runs(for: "me").first)
            let command = Task { try await h.runs.cancel(run) }
            try? await Task.sleep(for: .milliseconds(20))
            await source.hold.open()
            await first.value
            try await command.value
            #expect(h.runs.runs(for: "me").first?.state == .cancelled)
            #expect(await source.runRequests.count == 3)
        }

        @Test func forgetsTheCachesOfRemovedAccounts() async throws {
            let source = HeldRunSource(pushed: ["acme/api", "acme/web"], runs: ["acme/api": [.make(id: 1)]])
            let h = await NotchHarness(accounts: ["me", "gone"], runSource: source)
            await h.runs.refresh()
            let before = h.runs.cachedRepoCount
            let gone = try #require(h.accounts.accounts.first { $0.login == "gone" })
            h.accounts.remove(gone)
            await h.runs.refresh()
            #expect(h.runs.cachedRepoCount == before / 2)
            #expect(await source.retained?.keys.sorted() == ["me"])
        }
    }
}

struct TokenForgettingTests {
    private actor SlowCLI: GitHubCLI {
        let hold = Hold()
        private(set) var calls = 0

        func isInstalled() async -> Bool { true }
        func users() async -> [String] { [] }

        func token(for user: String) async throws -> String {
            calls += 1
            await hold.pass()
            return "token-\(calls)"
        }
    }

    @Test func aTokenArrivingAfterTheAccountWasRemovedIsNotKept() async throws {
        let cli = SlowCLI()
        let tokens = TokenProvider(cli: cli)
        await cli.hold.close()
        let asking = Task { try await tokens.token(for: "gone") }
        await cli.hold.waitForArrivals(1)
        await tokens.forget("gone")
        await cli.hold.open()
        _ = try await asking.value
        #expect(try await tokens.token(for: "gone") == "token-2")
    }

    @Test func runsForgetARejectedToken() async throws {
        let first = UUID().uuidString
        let session = StubURLProtocol.session(token: first, responses: [.init(status: 401, body: #"{ "message": "Bad credentials" }"#)])
        let cli = SlowCLI()
        let tokens = TokenProvider(cli: cli)
        await tokens.remember(first, for: "me")
        let source = GitHubRunSource(tokens: tokens, session: session)
        let account = Account(login: "me", avatarURL: nil)
        await #expect(throws: GitHubError.unauthorized) { try await source.runs(in: "acme/api", for: account) }
        #expect(try await tokens.token(for: "me") == "token-1")
    }
}

struct RunCacheTests {
    @Test func dropsJobsOfRunsThatAreGoneAndReposNoLongerWatched() async throws {
        let token = UUID().uuidString
        let run = { (id: Int) in
            """
            { "id": \(id), "name": "CI", "display_title": "x", "head_branch": "main", "event": "push", "status": "completed",
              "conclusion": "success", "html_url": "https://github.com/acme/api/actions/runs/\(id)",
              "created_at": "2026-10-01T12:00:00Z", "updated_at": "2026-10-01T12:00:00Z" }
            """
        }
        let session = StubURLProtocol.session(token: token, responses: [
            .init(status: 200, body: #"{ "workflow_runs": [\#(run(1)), \#(run(2))] }"#, headers: ["ETag": "\"a\""]),
            .init(status: 200, body: #"{ "jobs": [] }"#, headers: ["ETag": "\"j1\""]),
            .init(status: 200, body: #"{ "jobs": [] }"#, headers: ["ETag": "\"j2\""]),
            .init(status: 200, body: #"{ "workflow_runs": [\#(run(2))] }"#, headers: ["ETag": "\"b\""]),
        ])
        let tokens = TokenProvider(cli: FakeCLI())
        await tokens.remember(token, for: "me")
        let source = GitHubRunSource(tokens: tokens, session: session)
        let account = Account(login: "me", avatarURL: nil)
        let runs = try await source.runs(in: "acme/api", for: account)
        for run in runs { _ = try await source.jobs(of: run, for: account) }
        #expect(await source.cacheSizes.jobs == 2)
        _ = try await source.runs(in: "acme/api", for: account)
        #expect(await source.cacheSizes.jobs == 1)
        await source.retain(["me": []])
        #expect(await source.cacheSizes.runs == 0)
        #expect(await source.cacheSizes.jobs == 0)
        await source.retain([:])
        #expect(await source.cacheSizes.pushed == 0)
    }
}

@MainActor
struct SavedTabsTests {
    private let scratch = ScratchDefaults()

    @Test func skipsOnlyTheTabsItCannotRead() {
        let defaults = scratch.defaults
        let stored = Data("""
        [ { "id": "\(UUID().uuidString)", "name": "API", "query": "repo:acme/api", "sort": "someday" },
          { "query": "no name" },
          { "name": "Mine", "query": "author:@me", "preset": "future" } ]
        """.utf8)
        defaults.set(stored, for: .tabs)
        let accounts = AccountStore(defaults: defaults)
        #expect(accounts.tabs.map(\.name) == ["API", "Mine"])
        #expect(accounts.tabs[0].sort == nil)
        #expect(accounts.tabs[1].preset == nil)
        #expect(defaults.data(for: .tabs) == stored)
        #expect(defaults.data(for: .unreadableTabs) == stored)
    }

    @Test func unreadableTabsAreKeptAndNotReplacedByOldOnes() {
        let defaults = scratch.defaults
        let legacy = #"[ { "login": "me", "filters": [ { "name": "Old", "query": "repo:acme/old" } ] } ]"#
        defaults.set(Data(legacy.utf8), for: .accounts)
        let garbage = Data("not json".utf8)
        defaults.set(garbage, for: .tabs)
        defaults.set(garbage, for: .runTabs)
        let accounts = AccountStore(defaults: defaults)
        #expect(accounts.tabs.map(\.preset) == [.mine, .review])
        #expect(defaults.data(for: .tabs) == garbage)
        #expect(defaults.data(for: .unreadableTabs) == garbage)
        #expect(defaults.data(for: .runTabs) == garbage)
        #expect(defaults.data(for: .unreadableRunTabs) == garbage)
    }

    @Test func oldTabsMoveOverWhenThereAreNoneYet() {
        let defaults = scratch.defaults
        let legacy = #"[ { "login": "me", "filters": [ { "name": "Old", "query": "repo:acme/old" } ] } ]"#
        defaults.set(Data(legacy.utf8), for: .accounts)
        let accounts = AccountStore(defaults: defaults)
        #expect(accounts.tabs.map(\.name) == ["Old"])
        #expect(defaults.data(for: .unreadableTabs) == nil)
    }
}

@MainActor
struct ReadStateTests {
    private let scratch = ScratchDefaults()

    @Test func aPRMissingFromOneFetchKeepsWhatYouRead() {
        var now = Date(timeIntervalSince1970: 1_000_000)
        let tracker = ReadTracker(defaults: scratch.defaults) { now }
        tracker.sync(account: "me", prs: [])
        let pr = PullRequest.make(id: "PR_2", author: "ana")
        tracker.sync(account: "me", prs: [pr])
        tracker.markRead([pr])
        tracker.sync(account: "me", prs: [])
        now += 60
        tracker.sync(account: "me", prs: [pr])
        #expect(!tracker.isUnread(pr))
    }

    @Test func forgetsPRsNotSeenForTwoWeeks() {
        var now = Date(timeIntervalSince1970: 1_000_000)
        let tracker = ReadTracker(defaults: scratch.defaults) { now }
        tracker.sync(account: "me", prs: [.make(id: "PR_1")])
        now += ReadTracker.forgetAfter - 60
        tracker.sync(account: "me", prs: [])
        #expect(tracker.baselines.count == 1)
        now += 120
        tracker.sync(account: "me", prs: [])
        #expect(tracker.baselines.isEmpty)
    }

    @Test func aReviewRequestThatBlinksAlertsOnce() async {
        let defaults = scratch.defaults
        defaults.set(try? JSONEncoder().encode([Account(login: "me", avatarURL: nil)]), for: .accounts)
        let source = HeldSource(["me": Snapshot(mine: [], reviewRequests: [])])
        var now = Date(timeIntervalSince1970: 1_000_000)
        let store = PRStore(
            accounts: AccountStore(defaults: defaults),
            tracker: ReadTracker(defaults: defaults),
            source: source
        ) { now }
        var events: [PREvent] = []
        store.onEvents = { events += $0 }
        await store.refresh()
        let request = Snapshot(mine: [], reviewRequests: [.make(id: "PR_7", author: "ana")])
        await source.set("me", request)
        await store.refresh()
        await source.set("me", Snapshot(mine: [], reviewRequests: []))
        now += 60
        await store.refresh()
        await source.set("me", request)
        now += 60
        await store.refresh()
        #expect(events.map(\.kind) == [.reviewRequested])
        await source.set("me", Snapshot(mine: [], reviewRequests: []))
        now += 60
        await store.refresh()
        now += PRStore.reviewRequestMemory
        await source.set("me", request)
        await store.refresh()
        #expect(events.map(\.kind) == [.reviewRequested, .reviewRequested])
    }
}

struct DuplicatePRTests {
    @Test func theSamePRTwiceDoesNotCrash() {
        let pr = PullRequest.make(id: "PR_1", ci: .pending)
        let passed = PullRequest.make(id: "PR_1", ci: .success)
        let events = PREvent.diff(
            old: Snapshot(mine: [pr, pr], reviewRequests: []),
            new: Snapshot(mine: [passed, passed], reviewRequests: [])
        )
        #expect(events.map(\.kind) == [.ciPassed, .ciPassed])
    }
}
