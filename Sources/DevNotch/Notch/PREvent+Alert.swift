import SwiftUI

/// How each kind of PR event looks when it drops out of the notch.
extension PREvent {
    func alert(showingAccount: Bool) -> NotchAlert {
        NotchAlert(
            symbol: symbol,
            tint: tint,
            headline: headline,
            detail: "\(pr.repoName) #\(pr.number) · \(pr.title)",
            url: pr.url,
            account: showingAccount ? pr.account : nil
        )
    }

    private var headline: String {
        switch kind {
        case .ciPassed: "CI passed"
        case .ciFailed: "CI failed"
        case .approved: actor.map { "\($0) approved" } ?? "PR approved"
        case .changesRequested: actor.map { "\($0) requested changes" } ?? "Changes requested"
        case .reviewRequested:
            switch pr.reviewRequest {
            case .direct: "\(pr.author) requested your review"
            case .team(let teams): teams.first.map { "Review requested from \($0)" } ?? "Review requested from your team"
            }
        case .newComment: "New comment"
        }
    }

    private var symbol: String {
        switch kind {
        case .ciPassed: "checkmark.circle.fill"
        case .ciFailed: "xmark.octagon.fill"
        case .approved: "checkmark.seal.fill"
        case .changesRequested: "exclamationmark.bubble.fill"
        case .reviewRequested: pr.isDirectRequest ? "eyes" : "person.3.fill"
        case .newComment: "text.bubble.fill"
        }
    }

    private var tint: Color {
        switch kind {
        case .ciPassed, .approved: .green
        case .ciFailed: .red
        case .changesRequested: .orange
        case .reviewRequested: pr.isDirectRequest ? .purple : .indigo
        case .newComment: .blue
        }
    }
}
