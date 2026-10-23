import Foundation
@testable import Pullo
import Testing

extension NotchBehavior {
    @MainActor
    struct RunStoreTests {
        @Test func watchesPushedReposAndReposWithOpenPRs() async {
            let source = StubRunSource(pushed: ["acme/web", "acme/api"], runs: [
                "acme/web": [.make(id: 1, repo: "acme/web")],
                "acme/api": [.make(id: 2, repo: "acme/api")],
                "acme/infra": [.make(id: 3, repo: "acme/infra")],
            ])
            let h = await NotchHarness(mine: [.make(repo: "acme/infra"), .make(id: "PR_2", repo: "acme/api")], runSource: source)
            await h.runs.refresh()
            #expect(Set(h.runs.runs(for: "me").map(\.id)) == [1, 2, 3])
            #expect(await source.runRequests.sorted() == ["acme/api", "acme/infra", "acme/web"])
        }

        @Test func asksForJobsOnlyWhileARunIsRunning() async {
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [
                .make(id: 1, state: .running),
                .make(id: 2, state: .passed),
                .make(id: 3, state: .queued),
            ]])
            let h = await NotchHarness(runSource: source)
            await h.runs.refresh()
            #expect(await source.jobRequests == [1])
            #expect(h.runs.runs(for: "me").first { $0.id == 1 }?.jobs?.done == 2)
        }

        @Test func checksActiveReposOftenAndQuietOnesEveryMinute() async {
            let source = StubRunSource(pushed: ["acme/busy", "acme/quiet"], runs: [
                "acme/busy": [.make(id: 1, repo: "acme/busy", state: .running)],
                "acme/quiet": [.make(id: 2, repo: "acme/quiet")],
            ])
            let h = await NotchHarness(runSource: source)
            h.notch.open()
            await h.runs.refresh()
            h.now += 10
            await h.runs.refresh()
            #expect(await source.runRequests.filter { $0 == "acme/busy" }.count == 2)
            #expect(await source.runRequests.filter { $0 == "acme/quiet" }.count == 1)
            h.now += 50
            await h.runs.refresh()
            #expect(await source.runRequests.filter { $0 == "acme/quiet" }.count == 2)
        }

        @Test func showsTheErrorWhenGitHubCantBeReached() async {
            let h = await NotchHarness(runSource: StubRunSource(failsDiscovery: true))
            await h.runs.refresh()
            #expect(!h.runs.isLoaded("me"))
            #expect(h.runs.errors["me"]?.detail == "Not Found")
        }

        @Test func keepsTheRunsAndNotesTheProblemWhenGitHubStopsAnswering() async {
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [.make(id: 1, state: .running)]])
            let h = await NotchHarness(runSource: source)
            await h.runs.refresh()
            await source.failRuns(with: .offline)
            h.now += 60
            await h.runs.refresh()
            #expect(h.runs.runs(for: "me").map(\.id) == [1])
            #expect(h.runs.errors["me"]?.kind == .offline)
            await source.failRuns(with: nil)
            h.now += 60
            await h.runs.refresh()
            #expect(h.runs.errors["me"] == nil)
        }

        @Test func filtersRunsByWhoStartedThemAndDeploys() async {
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [
                .make(id: 1, state: .running, actor: "me"),
                .make(id: 2, state: .running, actor: "ana"),
                .make(id: 3, workflow: "Deploy production", actor: "ana"),
                .make(id: 4, actor: "ME"),
            ]])
            let h = await NotchHarness(runSource: source)
            await h.runs.refresh()
            #expect(h.actions.tab?.preset == .mine)
            #expect(h.actions.active.map(\.id) == [1])
            #expect(h.actions.recent.map(\.id) == [4])
            #expect(h.actions.activeCount(in: .builtIn(.everyone)) == 2)
            #expect(h.actions.runs(in: .builtIn(.deploys)).map(\.id) == [3])
            h.actions.select(h.actions.tabs[1])
            #expect(Set(h.actions.active.map(\.id)) == [1, 2])
        }

        @Test func stopsAskingForAnAccountsReposOnceOffline() async {
            let source = StubRunSource(pushed: ["acme/a", "acme/b", "acme/c"])
            let h = await NotchHarness(runSource: source)
            h.notch.open()
            await h.runs.refresh()
            await source.failRuns(with: .offline)
            h.now += 60
            await h.runs.refresh()
            #expect(await source.runRequests.count == 4)
            #expect(h.runs.errors["me"]?.kind == .offline)
        }

        @Test func parksARepoTheOrganizationBlocks() async {
            let source = StubRunSource(pushed: ["acme/api", "sso/secret"], runs: ["acme/api": [.make(id: 1)]])
            await source.failRuns(in: "sso/secret", with: .forbidden("Resource protected by organization SAML enforcement."))
            let h = await NotchHarness(runSource: source)
            await h.runs.refresh()
            #expect(h.runs.errors["me"] == nil)
            h.now += 3600
            await h.runs.refresh()
            #expect(await source.runRequests.filter { $0 == "sso/secret" }.count == 1)
            h.now += RunStore.parkingTime
            await h.runs.refresh()
            #expect(await source.runRequests.filter { $0 == "sso/secret" }.count == 2)
        }

        @Test func withThePanelClosedOnlyYourRunningReposAreCheckedOften() async {
            let source = StubRunSource(pushed: ["acme/mine", "acme/theirs", "acme/quiet"], runs: [
                "acme/mine": [.make(id: 1, repo: "acme/mine", state: .running, actor: "me")],
                "acme/theirs": [.make(id: 2, repo: "acme/theirs", state: .running, actor: "ana")],
                "acme/quiet": [.make(id: 3, repo: "acme/quiet")],
            ])
            let h = await NotchHarness(runSource: source)
            h.runs.setPanelOpen(false)
            await h.runs.refresh()
            #expect(await source.jobRequests == [1])
            for _ in 0..<9 {
                h.now += 30
                await h.runs.refresh()
            }
            let requests = await source.runRequests
            #expect(requests.filter { $0 == "acme/mine" }.count == 10)
            #expect(requests.filter { $0 == "acme/theirs" }.count == 1)
            #expect(requests.filter { $0 == "acme/quiet" }.count == 1)
            h.now += 30
            await h.runs.refresh()
            #expect(await source.runRequests.filter { $0 == "acme/theirs" }.count == 2)

            h.runs.setPanelOpen(true)
            h.now += 10
            await h.runs.refresh()
            #expect(await source.jobRequests.contains(2))
        }

        @Test func openingThePanelFollowsItsState() async {
            let h = await NotchHarness()
            #expect(!h.runs.isPanelOpen)
            h.notch.open()
            #expect(h.runs.isPanelOpen)
            h.notch.close()
            #expect(!h.runs.isPanelOpen)
            h.notch.open()
            #expect(h.runs.isPanelOpen)
        }
    }
}
