import Foundation

/// The groups of alerts that can be turned off in Settings.
enum AlertCategory: String, CaseIterable, Codable {
    case ciFailed, ciPassed, approved, changesRequested, directReview, teamReview, newComment, merged, closed

    init(_ event: PREvent) {
        switch event.kind {
        case .ciPassed: self = .ciPassed
        case .ciFailed: self = .ciFailed
        case .approved: self = .approved
        case .changesRequested: self = .changesRequested
        case .reviewRequested: self = event.pr.isDirectRequest ? .directReview : .teamReview
        case .newComment: self = .newComment
        case .merged: self = .merged
        case .closed: self = .closed
        }
    }

    var title: String {
        switch self {
        case .ciFailed: "CI failed"
        case .ciPassed: "CI passed"
        case .approved: "PR approved"
        case .changesRequested: "Changes requested"
        case .directReview: "Review requested from you"
        case .teamReview: "Review requested from your team"
        case .newComment: "New comment"
        case .merged: "PR merged"
        case .closed: "PR closed without merging"
        }
    }
}
