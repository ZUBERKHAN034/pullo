import Foundation

struct PullRequest: Identifiable, Equatable {
    let id: String
    let account: String
    let number: Int
    let title: String
    let url: URL
    let repo: String
    let branch: String
    let author: String
    let isDraft: Bool
    let createdAt: Date
    let updatedAt: Date
    let ci: CIState?
    let review: ReviewDecision?
    let hasConflict: Bool
    let othersComments: [Activity]
    let othersReviews: [Activity]
    let headOID: String
    let commitCount: Int
    let approvers: [String]
    let changeRequesters: [String]
    let reviewRequest: ReviewRequest
    let failedChecks: [FailedCheck]
    var avatars: [String: URL] = [:]
    var size: PRSize?
    var checks: CheckProgress?

    var isDirectRequest: Bool { reviewRequest == .direct }

    var othersCommentIDs: [String] { othersComments.map(\.id) }

    func displayLogin(_ login: String) -> String {
        guard let underscore = account.lastIndex(of: "_") else { return login }
        let suffix = account[underscore...]
        guard login.count > suffix.count, login.lowercased().hasSuffix(suffix.lowercased()) else { return login }
        return String(login.dropLast(suffix.count))
    }

    var repoName: String { repo.split(separator: "/").last.map(String.init) ?? repo }

    var isReadyToMerge: Bool {
        review == .approved && ci != .failure && ci != .pending && !hasConflict && !isDraft
    }

    var needsAction: Bool {
        ci == .failure || review == .changesRequested || hasConflict
    }
}
