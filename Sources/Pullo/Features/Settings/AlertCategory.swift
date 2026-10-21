import Foundation

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
        case .ciFailed: String(localized: "CI failed")
        case .ciPassed: String(localized: "CI passed")
        case .approved: String(localized: "PR approved")
        case .changesRequested: String(localized: "Changes requested")
        case .directReview: String(localized: "Review requested from you")
        case .teamReview: String(localized: "Review requested from your team")
        case .newComment: String(localized: "New comment")
        case .merged: String(localized: "PR merged")
        case .closed: String(localized: "PR closed without merging")
        }
    }
}
