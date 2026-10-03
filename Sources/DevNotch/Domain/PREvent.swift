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
            if before.review != pr.review {
                if pr.review == .approved {
                    events.append(PREvent(kind: .approved, pr: pr, actor: pr.approvers.last))
                }
                if pr.review == .changesRequested {
                    events.append(PREvent(kind: .changesRequested, pr: pr, actor: pr.changeRequesters.last))
                }
            }
            if !Set(pr.othersCommentIDs).subtracting(before.othersCommentIDs).isEmpty {
                events.append(PREvent(kind: .newComment, pr: pr, actor: nil))
            }
        }

        let oldReview = Set(old.reviewRequests.map(\.id))
        for pr in new.reviewRequests where !oldReview.contains(pr.id) {
            events.append(PREvent(kind: .reviewRequested, pr: pr, actor: pr.author))
        }
        return events
    }
}
