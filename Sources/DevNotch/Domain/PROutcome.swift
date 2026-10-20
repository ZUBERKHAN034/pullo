import Foundation

/// What became of a PR that left your open list.
struct PROutcome: Equatable {
    enum State: Equatable { case merged, closed, stillOpen }

    let id: String
    let state: State
    /// Who merged or closed it.
    let actor: String?
    let actorAvatar: URL?
}

extension PROutcome {
    /// Merges and closes are news unless you did them yourself; a PR that only fell out of the list isn't.
    func event(for pr: PullRequest) -> PREvent? {
        guard actor?.caseInsensitiveCompare(pr.account) != .orderedSame else { return nil }
        switch state {
        case .merged: return PREvent(kind: .merged, pr: pr, actor: actor, actorAvatar: actorAvatar)
        case .closed: return PREvent(kind: .closed, pr: pr, actor: actor, actorAvatar: actorAvatar)
        case .stillOpen: return nil
        }
    }
}
