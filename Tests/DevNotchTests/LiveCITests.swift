import AppKit
@testable import DevNotch
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
            #expect(h.notch.liveCI?.pr.id == "PR_new")
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
            #expect(h.notch.liveCI?.trailingText == "#\(h.notch.liveCI?.pr.number ?? 0)")
            h.settings.liveCILabel = .checks
            #expect(h.notch.liveCI?.trailingText == "3/5")
            #expect(h.notch.liveCI?.showsNumberBeside == false)
            let narrow = h.notch.layout.size(for: .closed).width
            h.settings.liveCILabel = .both
            #expect(h.notch.liveCI?.trailingText == "3/5")
            #expect(h.notch.liveCI?.showsNumberBeside == true)
            #expect(h.notch.layout.size(for: .closed).width > narrow)
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
