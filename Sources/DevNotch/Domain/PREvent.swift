import Foundation

/// Something that changed on a PR between two polls.
struct PREvent: Equatable {
    enum Kind: CaseIterable {
        case ciPassed, ciFailed, approved, changesRequested, reviewRequested, newComment
    }

    let kind: Kind
    let pr: PullRequest
    /// Who caused it, when GitHub tells us.
    let actor: String?
}

extension PREvent {
    /// Compares two polls and turns state transitions into alerts.
    static func diff(old: Snapshot, new: Snapshot) -> [PREvent] {
        var events: [PREvent] = []
        let oldMine = Dictionary(uniqueKeysWithValues: old.mine.map { ($0.id, $0) })

        for pr in new.mine {
            guard let before = oldMine[pr.id] else { continue }
            if before.ci != pr.ci {
                if pr.ci == .success { events.append(PREvent(kind: .ciPassed, pr: pr, actor: nil)) }
                if pr.ci == .failure { events.append(PREvent(kind: .ciFailed, pr: pr, actor: nil)) }
            }
            // Each reviewer is news, so a second approval alerts too, and so do repos that don't require reviews,
            // where the PR's review decision never changes.
            let newApprovers = pr.approvers.filter { !before.approvers.contains($0) }
            let newRequesters = pr.changeRequesters.filter { !before.changeRequesters.contains($0) }
            if let approver = newApprovers.last {
                events.append(PREvent(kind: .approved, pr: pr, actor: approver))
            }
            if let requester = newRequesters.last {
                events.append(PREvent(kind: .changesRequested, pr: pr, actor: requester))
            }
            // Plain comments and "comment" reviews; approvals and change requests already alerted above.
            let newActivity = pr.othersComments.filter { !before.othersCommentIDs.contains($0.id) }
                + pr.othersReviews.filter { review in
                    !before.othersReviews.contains { $0.id == review.id }
                        && !newApprovers.contains(review.author) && !newRequesters.contains(review.author)
                }
            let commenters = Set(newActivity.map(\.author))
            if !newActivity.isEmpty {
                events.append(PREvent(kind: .newComment, pr: pr, actor: commenters.count == 1 ? commenters.first : nil))
            }
        }

        let oldReview = Set(old.reviewRequests.map(\.id))
        for pr in new.reviewRequests where !oldReview.contains(pr.id) {
            events.append(PREvent(kind: .reviewRequested, pr: pr, actor: pr.author))
        }
        return events
    }
}
