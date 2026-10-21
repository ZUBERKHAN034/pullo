@testable import DevNotch
import Foundation
import Testing

extension NotchBehavior {
    @MainActor
    struct RunDetailTests {
        private func harness(_ source: StubRunSource) async -> NotchHarness {
            let h = await NotchHarness(runSource: source)
            await h.runs.refresh()
            return h
        }

        @Test func opensARunWithItsJobs() async {
            let run = WorkflowRun.make(id: 7, state: .failed)
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [run]])
            await source.setJobs([.make(id: 1, name: "test", state: .failed, failedStep: "Run tests")], of: 7)
            let h = await harness(source)
            h.actions.open(run)
            await h.runs.loadJobs(of: run)
            #expect(h.actions.openedRun?.id == 7)
            #expect(h.actions.openedJobs?.first?.failedStep == "Run tests")
        }

        @Test func keepsTheJobsOfTheOpenRunFreshAfterItFinishes() async {
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [.make(id: 7, state: .passed)]])
            let h = await harness(source)
            #expect(await source.jobRequests.isEmpty)
            h.actions.open(.make(id: 7, state: .passed))
            h.now += 60
            await h.runs.refresh()
            let watching = await source.jobRequests.count
            #expect(watching >= 1)
            h.actions.back()
            h.now += 60
            await h.runs.refresh()
            #expect(await source.jobRequests.count == watching)
        }

        @Test func escapeGoesBackToTheListBeforeClosing() async {
            let run = WorkflowRun.make(id: 7)
            let h = await harness(StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [run]]))
            h.notch.open()
            h.notch.show(.actions)
            h.actions.open(run)
            #expect(h.notch.perform(.close))
            #expect(h.actions.openedRun == nil)
            #expect(h.notch.state == .open)
            #expect(h.notch.perform(.close))
            #expect(h.notch.state != .open)
        }

        @Test func rerunsTheFailedJobsAndChecksTheRepoAgain() async {
            let run = WorkflowRun.make(id: 7, state: .failed)
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [run]])
            let h = await harness(source)
            h.actions.open(run)
            await h.actions.perform(.rerunFailedJobs)
            #expect(await source.commands == ["rerun 7"])
            #expect(await source.runRequests.count == 2)
            #expect(h.list.toast == "Re-running the failed jobs")
            #expect(h.actions.running == nil)
        }

        @Test func cancelsARun() async {
            let run = WorkflowRun.make(id: 7, state: .running)
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [run]])
            let h = await harness(source)
            h.actions.open(run)
            await h.actions.perform(.cancel)
            #expect(await source.commands == ["cancel 7"])
            #expect(h.list.toast == "Cancelling the run")
        }

        @Test func saysSoWhenGitHubRefuses() async {
            let run = WorkflowRun.make(id: 7, state: .running)
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [run]])
            await source.failCommands()
            let h = await harness(source)
            h.actions.open(run)
            await h.actions.perform(.cancel)
            #expect(h.list.toast == "Couldn't cancel the run")
        }
    }
}
