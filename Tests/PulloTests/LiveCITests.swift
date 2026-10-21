import AppKit
@testable import Pullo
import Testing

extension NotchBehavior {
    @MainActor
    struct LiveCITests {
        private static func running(_ id: String, minutesAgo: Double, account: String = "me") -> PullRequest {
            .make(
                id: id,
                account: account,
                ci: .pending,
                updatedAt: Date(timeIntervalSinceNow: -minutesAgo * 60),
                checks: CheckProgress(done: 3, total: 5)
            )
        }

        @Test func showsTheMostRecentRunAndCountsTheRest() async {
            let h = await NotchHarness(mine: [
                Self.running("PR_old", minutesAgo: 30),
                Self.running("PR_new", minutesAgo: 1),
                .make(id: "PR_done", ci: .success),
            ])
            #expect(h.notch.liveCI?.id == "PR_new")
            #expect(h.notch.liveCI?.othersRunning == 1)
        }

        @Test func widensTheClosedNotchWhileChecksRun() async {
            let idle = await NotchHarness()
            let busy = await NotchHarness(mine: [Self.running("PR_1", minutesAgo: 1)])
            #expect(idle.notch.liveCI == nil)
            #expect(busy.notch.layout.size(for: .closed).width > idle.notch.layout.size(for: .closed).width)
            #expect(busy.notch.layout.hitRect(for: .closed).width > idle.notch.layout.hitRect(for: .closed).width)
        }

        @Test func staysHiddenWhenTurnedOffOrTheAccountIsMuted() async {
            let h = await NotchHarness(accounts: ["me", "work"], mine: [Self.running("PR_1", minutesAgo: 1, account: "work")])
            #expect(h.notch.liveCI != nil)
            h.settings.mutedAccounts.insert("work")
            #expect(h.notch.liveCI == nil)
            h.settings.mutedAccounts.remove("work")
            h.settings.showsLiveCI = false
            #expect(h.notch.liveCI == nil)
        }

        @Test func followsTheChosenLabel() async {
            let h = await NotchHarness(mine: [Self.running("PR_1", minutesAgo: 1)])
            #expect(h.notch.liveCI?.trailingText == "#383")
            h.settings.liveCILabel = .checks
            #expect(h.notch.liveCI?.trailingText == "3/5")
            #expect(h.notch.liveCI?.showsNumberBeside == false)
            let narrow = h.notch.layout.size(for: .closed).width
            h.settings.liveCILabel = .both
            #expect(h.notch.liveCI?.trailingText == "3/5")
            #expect(h.notch.liveCI?.showsNumberBeside == true)
            #expect(h.notch.layout.size(for: .closed).width > narrow)
        }

        @Test func showsYourOwnRunsWithTheWorkflowName() async {
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [
                .make(id: 1, workflow: "Deploy", state: .running, actor: "me", createdAt: .now),
                .make(id: 2, workflow: "Nightly", state: .running, actor: "ana", createdAt: .now),
            ]])
            let h = await NotchHarness(runSource: source)
            await h.runs.refresh()
            #expect(h.notch.liveCI?.name == "Deploy")
            #expect(h.notch.liveCI?.othersRunning == 0)
            h.settings.liveCILabel = .checks
            #expect(h.notch.liveCI?.trailingText == "2/5")
        }

        @Test func aPRsRunIsNotCountedTwice() async {
            let run = WorkflowRun.make(id: 1, repo: "acme/acme-api", state: .running, createdAt: .now, pullRequest: 383)
            let source = StubRunSource(pushed: ["acme/acme-api"], runs: ["acme/acme-api": [run]])
            let h = await NotchHarness(mine: [Self.running("PR_1", minutesAgo: 1)], runSource: source)
            await h.runs.refresh()
            #expect(h.notch.liveCI?.id == "PR_1")
            #expect(h.notch.liveCI?.othersRunning == 0)
        }

        @Test func turnsRedAsSoonAsAJobFails() {
            let failing = WorkflowRun.make(id: 1, state: .running, createdAt: .now)
            var live = LiveCI(run: failing)
            #expect(!live.failing)
            var withJobs = failing
            withJobs.jobs = JobProgress(done: 2, total: 5, failed: 1, current: "deploy")
            live = LiveCI(run: withJobs)
            #expect(live.failing)
            #expect(live.checksText == "2/5")
        }

        @Test func flashesTheResultWhenYourRunFinishes() async {
            let source = StubRunSource(pushed: ["acme/api"], runs: ["acme/api": [.make(id: 1, workflow: "Deploy", state: .running)]])
            let h = await NotchHarness(runSource: source)
            await h.runs.refresh()
            await source.set([.make(id: 1, workflow: "Deploy", state: .failed)], in: "acme/api")
            h.now += 10
            await h.runs.refresh()
            #expect(h.notch.liveCI?.finished == .failure)
            #expect(h.notch.liveCI?.name == "Deploy")
            await h.clock.advance(by: .seconds(2))
            #expect(h.notch.liveCI == nil)
        }

        @Test func showsTheResultBeforeTheAlert() async {
            let h = await NotchHarness()
            let pr = PullRequest.make(ci: .failure, checks: CheckProgress(done: 5, total: 5))
            h.notch.enqueue(events: [PREvent(kind: .ciFailed, pr: pr, actor: nil)])
            #expect(h.notch.liveCI?.finished == .failure)
            #expect(h.notch.state == .closed)
            await h.clock.advance(by: .seconds(2))
            #expect(h.notch.liveCI == nil)
            #expect(h.notch.state == .peek)
        }

        @Test func otherAlertsDoNotWait() async {
            let h = await NotchHarness()
            h.notch.enqueue(events: [PREvent(kind: .approved, pr: .make(), actor: "octocat")])
            #expect(h.notch.liveCI == nil)
            #expect(h.notch.state == .peek)
        }
    }
}
