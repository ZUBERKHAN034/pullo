import Foundation

struct PREvent: Equatable {
    enum Kind: CaseIterable {
        case ciPassed, ciFailed, approved, changesRequested, reviewRequested, newComment, merged, closed
    }

    let kind: Kind
    let pr: PullRequest
    let actor: String?
    var actorAvatar: URL?
}

extension PREvent {
    static func diff(old: Snapshot, new: Snapshot) -> [PREvent] {
        var events: [PREvent] = []
        let oldMine = Dictionary(uniqueKeysWithValues: old.mine.map { ($0.id, $0) })

        for pr in new.mine {
            guard let before = oldMine[pr.id] else { continue }
            if before.ci != pr.ci {
                if pr.ci == .success { events.append(PREvent(kind: .ciPassed, pr: pr, actor: nil)) }
                if pr.ci == .failure { events.append(PREvent(kind: .ciFailed, pr: pr, actor: nil)) }
            }
            let newApprovers = pr.approvers.filter { !before.approvers.contains($0) }
            let newRequesters = pr.changeRequesters.filter { !before.changeRequesters.contains($0) }
            if let approver = newApprovers.last {
                events.append(PREvent(kind: .approved, pr: pr, actor: approver))
            }
            if let requester = newRequesters.last {
                events.append(PREvent(kind: .changesRequested, pr: pr, actor: requester))
            }
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
