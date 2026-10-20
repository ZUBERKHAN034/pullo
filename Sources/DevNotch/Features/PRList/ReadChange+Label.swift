import Foundation

extension ReadChange {
    var label: String {
        switch self {
        case .newReviewRequest: "New review request"
        case .comments(let count): count == 1 ? "1 new comment" : "\(count) new comments"
        case .reviewed(by: let reviewers): reviewers.count == 1 ? "\(reviewers[0]) reviewed" : "\(reviewers.count) people reviewed"
        case .approved: "Approved"
        case .changesRequested: "Changes requested"
        case .ciFailed: "CI failed"
        case .ciPassed: "CI passed"
        case .commits(let count): count == 1 ? "1 new commit" : "\(count) new commits"
        case .forcePush: "force-push"
        }
    }
}
