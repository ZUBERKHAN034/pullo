import Foundation

struct PROutcome: Equatable {
    enum State: Equatable { case merged, closed, stillOpen }

    let id: String
    let state: State
    let actor: String?
    let actorAvatar: URL?
}

extension PROutcome {
    func event(for pr: PullRequest) -> PREvent? {
        guard actor?.caseInsensitiveCompare(pr.account) != .orderedSame else { return nil }
        switch state {
        case .merged: return PREvent(kind: .merged, pr: pr, actor: actor, actorAvatar: actorAvatar)
        case .closed: return PREvent(kind: .closed, pr: pr, actor: actor, actorAvatar: actorAvatar)
        case .stillOpen: return nil
        }
    }
}
