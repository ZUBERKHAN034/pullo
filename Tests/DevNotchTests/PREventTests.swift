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

    @Test func secondApprovalAlertsToo() {
        let events = PREvent.diff(
            old: Snapshot(mine: [.make(review: .approved, approvers: ["octavio"])], reviewRequests: []),
            new: Snapshot(mine: [.make(review: .approved, approvers: ["octavio", "marina"])], reviewRequests: [])
        )
        #expect(events.map(\.kind) == [.approved])
        #expect(events.first?.actor == "marina")
    }

    @Test func approvalAlertsWithoutRequiredReviews() {
        // Repos that don't require reviews never set a review decision.
        #expect(kinds([.make(review: nil)], [.make(review: nil, approvers: ["octavio"])]) == [.approved])
    }

    @Test func changesRequestedNamesWho() {
        let events = PREvent.diff(
            old: Snapshot(mine: [.make()], reviewRequests: []),
            new: Snapshot(mine: [.make(review: .changesRequested, changeRequesters: ["marina"])], reviewRequests: [])
        )
        #expect(events.map(\.kind) == [.changesRequested])
        #expect(events.first?.actor == "marina")
    }

    @Test func newCommentNamesWhoCommented() {
        let events = PREvent.diff(
            old: Snapshot(mine: [.make(comments: ["c1"])], reviewRequests: []),
            new: Snapshot(mine: [.make(comments: ["c1", "c2"])], reviewRequests: [])
        )
        #expect(events.map(\.kind) == [.newComment])
        #expect(events.first?.actor == "octocat")
    }

    @Test func commentReviewAlertsAsComment() {
        let review = Activity(id: "r1", author: "marina")
        #expect(kinds([.make()], [.make(reviews: [review])]) == [.newComment])
    }

    @Test func approvalIsNotAlsoAComment() {
        let review = Activity(id: "r1", author: "octavio")
        #expect(kinds([.make()], [.make(reviews: [review], approvers: ["octavio"])]) == [.approved])
    }

    @Test func newReviewRequest() {
        #expect(kinds([], [], reviewOld: [], reviewNew: [.make(id: "PR_2")]) == [.reviewRequested])
    }

    @Test func newPRsOfYourOwnAreNotAlerts() {
        #expect(kinds([], [.make()]).isEmpty)
    }
}

struct StackedAlertTests {
    @Test func whatNeedsYouComesFirst() {
        let pr = PullRequest.make()
        let alerts = [
            PREvent(kind: .approved, pr: pr, actor: "octavio"),
            PREvent(kind: .newComment, pr: pr, actor: "marina"),
            PREvent(kind: .ciFailed, pr: pr, actor: nil),
        ].map { $0.alert(showingAccount: false) }
        let headlines = NotchAlert.summary(of: alerts).stack.map(\.headline)
        #expect(headlines == ["CI failed", "marina commented", "octavio approved"])
    }
}
