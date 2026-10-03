import Testing
@testable import DevNotch

struct PREventTests {
    private func kinds(_ old: [PullRequest], _ new: [PullRequest], reviewOld: [PullRequest] = [], reviewNew: [PullRequest] = []) -> [PREvent.Kind] {
        PREvent.diff(
            old: Snapshot(mine: old, reviewRequests: reviewOld),
            new: Snapshot(mine: new, reviewRequests: reviewNew)
        ).map(\.kind)
    }

    @Test func nothingChanged() {
        #expect(kinds([.make()], [.make()]).isEmpty)
    }

    @Test func ciTransitions() {
        #expect(kinds([.make(ci: .pending)], [.make(ci: .failure)]) == [.ciFailed])
        #expect(kinds([.make(ci: .failure)], [.make(ci: .success)]) == [.ciPassed])
        #expect(kinds([.make(ci: .success)], [.make(ci: .pending)]).isEmpty)
    }

    @Test func approvalNamesWhoApproved() {
        let events = PREvent.diff(
            old: Snapshot(mine: [.make()], reviewRequests: []),
            new: Snapshot(mine: [.make(review: .approved, approvers: ["octavio"])], reviewRequests: [])
        )
        #expect(events.map(\.kind) == [.approved])
        #expect(events.first?.actor == "octavio")
    }

    @Test func newCommentFromSomeoneElse() {
        #expect(kinds([.make(comments: ["c1"])], [.make(comments: ["c1", "c2"])]) == [.newComment])
    }

    @Test func newReviewRequest() {
        #expect(kinds([], [], reviewOld: [], reviewNew: [.make(id: "PR_2")]) == [.reviewRequested])
    }

    @Test func newPRsOfYourOwnAreNotAlerts() {
        #expect(kinds([], [.make()]).isEmpty)
    }
}
