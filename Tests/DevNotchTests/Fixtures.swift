import Foundation
@testable import DevNotch

extension PullRequest {
    static func make(
        id: String = "PR_1",
        account: String = "me",
        number: Int = 383,
        title: String = "feat: canal web",
        repo: String = "acme/acme-api",
        branch: String = "feat/canal-web",
        author: String = "me",
        ci: CIState? = .success,
        conflict: Bool = false,
        draft: Bool = false,
        review: ReviewDecision? = nil,
        comments: [String] = [],
        reviews: [Activity] = [],
        headOID: String = "abc",
        commitCount: Int = 1,
        approvers: [String] = [],
        changeRequesters: [String] = [],
        reviewRequest: ReviewRequest = .direct
    ) -> PullRequest {
        PullRequest(
            id: id,
            account: account,
            number: number,
            title: title,
            url: URL(string: "https://github.com/\(repo)/pull/\(number)")!,
            repo: repo,
            branch: branch,
            author: author,
            isDraft: draft,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            ci: ci,
            review: review,
            hasConflict: conflict,
            othersComments: comments.map { Activity(id: $0, author: "octocat") },
            othersReviews: reviews,
            headOID: headOID,
            commitCount: commitCount,
            approvers: approvers,
            changeRequesters: changeRequesters,
            reviewRequest: reviewRequest,
            failedChecks: []
        )
    }
}
