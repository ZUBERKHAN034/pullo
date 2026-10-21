@testable import Pullo
import Testing

struct PRStatusTests {
    @Test func mostUrgentComesFirst() {
        let pr = PullRequest.make(ci: .failure, review: .changesRequested)
        #expect(pr.statuses(mine: true) == [.ciFailed, .changesRequested])
    }

    @Test func conflictOutranksEverything() {
        let pr = PullRequest.make(ci: .failure, conflict: true, review: .changesRequested)
        #expect(pr.statuses(mine: true) == [.conflict, .ciFailed, .changesRequested])
    }

    @Test func draftAndRunningChecks() {
        #expect(PullRequest.make(ci: .pending, draft: true).statuses(mine: true) == [.ciRunning, .draft])
    }

    @Test func reviewStateOnlyCountsOnYourOwnPRs() {
        let pr = PullRequest.make(ci: .success, review: .approved)
        #expect(pr.statuses(mine: true) == [.readyToMerge, .ciPassed])
        #expect(pr.statuses(mine: false) == [.ciPassed])
    }

    @Test func passingOrMissingChecksHaveNoWord() {
        #expect(PRStatus.ciPassed.label == nil)
        #expect(PRStatus.noChecks.label == nil)
        #expect(PullRequest.make(ci: nil).statuses(mine: false) == [.noChecks])
    }
}
