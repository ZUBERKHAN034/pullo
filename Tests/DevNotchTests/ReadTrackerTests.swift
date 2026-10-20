@testable import DevNotch
import Foundation
import Testing

@MainActor
struct ReadTrackerTests {
    private let scratch = ScratchDefaults()
    private let tracker: ReadTracker

    init() {
        tracker = ReadTracker(defaults: scratch.defaults)
    }

    @Test func firstSyncStartsEverythingAsRead() {
        let pr = PullRequest.make()
        tracker.sync(account: "me", prs: [pr])
        #expect(tracker.reasons(for: pr).isEmpty)
    }

    @Test func reviewRequestsAppearingLaterAreNew() {
        tracker.sync(account: "me", prs: [])
        let theirs = PullRequest.make(id: "PR_2", author: "octavio")
        tracker.sync(account: "me", prs: [theirs])
        #expect(tracker.reasons(for: theirs) == ["New review request"])
    }

    @Test func yourOwnNewPRIsNotUnread() {
        tracker.sync(account: "me", prs: [])
        let mine = PullRequest.make(id: "PR_1", author: "me")
        tracker.sync(account: "me", prs: [mine])
        #expect(tracker.reasons(for: mine).isEmpty)
    }

    @Test func forgettingAnAccountStartsItFresh() {
        tracker.sync(account: "me", prs: [])
        let theirs = PullRequest.make(id: "PR_2", author: "octavio")
        tracker.sync(account: "me", prs: [theirs])
        tracker.forget(account: "me")
        #expect(tracker.baselines.isEmpty)
        // Added back, it's a first sync again, so nothing lights up.
        tracker.sync(account: "me", prs: [theirs])
        #expect(tracker.reasons(for: theirs).isEmpty)
    }

    @Test func explainsWhatChanged() {
        let before = PullRequest.make(ci: .pending, comments: ["c1"])
        tracker.sync(account: "me", prs: [before])
        let after = PullRequest.make(
            ci: .failure,
            review: .approved,
            comments: ["c1", "c2", "c3"],
            reviews: [Activity(id: "r1", author: "octavio")]
        )
        #expect(tracker.reasons(for: after) == ["2 new comments", "octavio reviewed", "Approved", "CI failed"])
    }

    @Test func openingMarksRead() {
        tracker.sync(account: "me", prs: [.make(comments: [])])
        let changed = PullRequest.make(comments: ["c1"])
        #expect(tracker.isUnread(changed))
        tracker.markRead([changed])
        #expect(!tracker.isUnread(changed))
    }

    @Test func commitsOnlyMatterOnOtherPeoplesPRs() {
        let mine = PullRequest.make(id: "PR_1", author: "me", headOID: "a", commitCount: 1)
        let theirs = PullRequest.make(id: "PR_2", author: "octavio", headOID: "a", commitCount: 3)
        tracker.sync(account: "me", prs: [mine, theirs])

        #expect(tracker.reasons(for: .make(id: "PR_1", author: "me", headOID: "b", commitCount: 2)).isEmpty)
        #expect(tracker.reasons(for: .make(id: "PR_2", author: "octavio", headOID: "b", commitCount: 5)) == ["2 new commits"])
        #expect(tracker.reasons(for: .make(id: "PR_2", author: "octavio", headOID: "c", commitCount: 3)) == ["force-push"])
    }
}
