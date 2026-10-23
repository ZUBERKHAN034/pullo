import Foundation

struct ReadBaseline: Codable, Equatable {
    var commentIDs: Set<String>
    var reviewIDs: Set<String>
    var headOID: String
    var commitCount: Int
    var ci: CIState?
    var review: ReviewDecision?
    var isNew = false
    var lastSeen: Date?

    init(_ pr: PullRequest, isNew: Bool = false) {
        commentIDs = Set(pr.othersCommentIDs)
        reviewIDs = Set(pr.othersReviews.map(\.id))
        headOID = pr.headOID
        commitCount = pr.commitCount
        ci = pr.ci
        review = pr.review
        self.isNew = isNew
    }
}
