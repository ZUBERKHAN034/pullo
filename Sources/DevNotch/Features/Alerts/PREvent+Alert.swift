import SwiftUI

extension PREvent {
    func alert(showingAccount: Bool) -> NotchAlert {
        NotchAlert(
            symbol: symbol,
            tint: tint,
            headline: headline,
            detail: "\(pr.repoName) #\(pr.number) · \(pr.title)",
            url: pr.url,
            pr: pr,
            actor: actor,
            actorAvatar: actorAvatar ?? actor.flatMap { pr.avatars[$0] },
            account: showingAccount ? pr.account : nil,
            priority: priority
        )
    }

    private var priority: Int {
        switch kind {
        case .ciFailed, .changesRequested: 3
        case .closed: 2
        case .merged: 1
        case .reviewRequested: pr.isDirectRequest ? 2 : 0
        case .newComment: 1
        case .approved, .ciPassed: 0
        }
    }

    private var headline: String {
        switch kind {
        case .ciPassed: String(localized: "CI passed")
        case .ciFailed: String(localized: "CI failed")
        case .approved: name.map { String(localized: "\($0) approved") } ?? String(localized: "PR approved")
        case .changesRequested: name.map { String(localized: "\($0) requested changes") } ?? String(localized: "Changes requested")
        case .reviewRequested:
            switch pr.reviewRequest {
            case .direct: String(localized: "\(pr.displayLogin(pr.author)) requested your review")
            case .team(let teams): teams.first
                .map { String(localized: "Review requested from \($0)") } ?? String(localized: "Review requested from your team")
            }
        case .newComment: name.map { String(localized: "\($0) commented") } ?? String(localized: "New comments")
        case .merged: name.map { String(localized: "\($0) merged your PR") } ?? String(localized: "PR merged")
        case .closed: name.map { String(localized: "\($0) closed your PR") } ?? String(localized: "PR closed")
        }
    }

    private var name: String? { actor.map(pr.displayLogin) }

    private var symbol: String {
        switch kind {
        case .ciPassed: "checkmark.circle.fill"
        case .ciFailed: "xmark.octagon.fill"
        case .approved: "checkmark.seal.fill"
        case .changesRequested: "exclamationmark.bubble.fill"
        case .reviewRequested: pr.isDirectRequest ? "eyes" : "person.3.fill"
        case .newComment: "text.bubble.fill"
        case .merged: "arrow.triangle.merge"
        case .closed: "xmark"
        }
    }

    private var tint: Color {
        switch kind {
        case .ciPassed, .approved: .green
        case .ciFailed: .red
        case .changesRequested: .orange
        case .reviewRequested: pr.isDirectRequest ? .purple : .indigo
        case .newComment: .blue
        case .merged: .purple
        case .closed: .red
        }
    }
}
