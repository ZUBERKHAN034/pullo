import Foundation
@testable import Pullo
import Testing

struct RunTabTests {
    @Test func matchesEveryFieldItHas() {
        let deploy = WorkflowRun.make(repo: "acme/api", workflow: "Deploy production", branch: "release/1.4", actor: "ana")
        #expect(RunTab(name: "x", repo: "acme/api").includes(deploy, login: "me"))
        #expect(RunTab(name: "x", repo: "API").includes(deploy, login: "me"))
        #expect(!RunTab(name: "x", repo: "acme/web").includes(deploy, login: "me"))
        #expect(RunTab(name: "x", workflow: "deploy").includes(deploy, login: "me"))
        #expect(RunTab(name: "x", branch: "release/*").includes(deploy, login: "me"))
        #expect(!RunTab(name: "x", branch: "release").includes(deploy, login: "me"))
        #expect(RunTab(name: "x", startedBy: .user, user: "@Ana").includes(deploy, login: "me"))
        #expect(!RunTab(name: "x", startedBy: .me).includes(deploy, login: "me"))
        #expect(!RunTab(name: "x", repo: "acme/api", workflow: "ci").includes(deploy, login: "me"))
    }

    @Test func readsTheEventGitHubSends() {
        #expect(RunTab(name: "x", event: .pullRequest).includes(.make(event: "pull_request_target"), login: "me"))
        #expect(RunTab(name: "x", event: .manual).includes(.make(event: "workflow_dispatch"), login: "me"))
        #expect(!RunTab(name: "x", event: .schedule).includes(.make(event: "push"), login: "me"))
    }

    @Test func countsARunningRunWithAFailedJobAsFailing() {
        var running = WorkflowRun.make(state: .running)
        let failing = RunTab(name: "x", status: .failing)
        #expect(!failing.includes(running, login: "me"))
        running.jobs = JobProgress(done: 2, total: 4, failed: 1, current: nil)
        #expect(failing.includes(running, login: "me"))
        #expect(failing.includes(.make(state: .failed), login: "me"))
        #expect(RunTab(name: "x", status: .active).includes(.make(state: .waiting), login: "me"))
    }

    @Test func needsANameAndTheUserWhenItsSomeoneElse() {
        #expect(!RunTab(name: " ").isComplete)
        #expect(!RunTab(name: "Ana", startedBy: .user).isComplete)
        #expect(RunTab(name: "Ana", startedBy: .user, user: "ana").isComplete)
    }

    @MainActor @Test func accountsSavedBeforeKeepTheirTabs() throws {
        let scratch = ScratchDefaults()
        let prod = RunTab(name: "Prod", branch: "main")
        let old = try [
            #"{"login":"me","filters":[]}"#,
            #"{"login":"work","runTabs":\#(String(decoding: JSONEncoder().encode([prod]), as: UTF8.self))}"#,
        ]
        scratch.defaults.set(Data("[\(old.joined(separator: ","))]".utf8), for: .accounts)
        let accounts = AccountStore(defaults: scratch.defaults)
        #expect(accounts.accounts.map(\.login) == ["me", "work"])
        #expect(accounts.runTabs.map(\.preset) == [.mine, .everyone, .deploys, nil])
        #expect(accounts.runTabs.map(\.account) == ["me", "me", "me", "work"])
        #expect(accounts.tabs.map(\.preset) == [.mine, .review])
    }
}

extension NotchBehavior {
    @MainActor
    struct ActionsTabsTests {
        @Test func showsTheTabsOfTheAccount() async {
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [
                .make(id: 1, branch: "main", state: .failed, actor: "ana"),
                .make(id: 2, branch: "feat/x", state: .failed, actor: "ana"),
                .make(id: 3, branch: "main", state: .running, actor: "me"),
            ]])
            let h = await NotchHarness(runSource: source)
            await h.runs.refresh()
            let failing = RunTab(name: "Failing on main", branch: "main", status: .failing)
            h.accounts.setRunTabs([failing] + RunTab.defaults)
            #expect(h.actions.tabs.first?.name == "Failing on main")
            #expect(h.actions.recent.map(\.id) == [1])
            #expect(h.actions.myActiveCount == 1)
            h.accounts.setRunTabs(RunTab.defaults)
            #expect(h.actions.tab?.preset == .mine)
        }
    }
}
