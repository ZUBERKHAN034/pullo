import Foundation

extension ReadChange {
    var label: String {
        switch self {
        case .newReviewRequest: String(localized: "New review request")
        case .comments(let count): count == 1 ? String(localized: "1 new comment") : String(localized: "\(count) new comments")
        case .reviewed(by: let reviewers): reviewers
            .count == 1 ? String(localized: "\(reviewers[0]) reviewed") : String(localized: "\(reviewers.count) people reviewed")
        case .approved: String(localized: "Approved")
        case .changesRequested: String(localized: "Changes requested")
        case .ciFailed: String(localized: "CI failed")
        case .ciPassed: String(localized: "CI passed")
        case .commits(let count): count == 1 ? String(localized: "1 new commit") : String(localized: "\(count) new commits")
        case .forcePush: String(localized: "force-push")
        }
    }
}
