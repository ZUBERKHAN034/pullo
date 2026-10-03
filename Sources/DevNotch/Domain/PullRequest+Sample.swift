import Foundation

extension PullRequest {
    static let sample = PullRequest(
        id: "sample",
        account: "octocat",
        number: 42,
        title: "feat: show PRs in the notch",
        url: URL(string: "https://github.com")!,
        repo: "jrdan/devnotch",
        branch: "feat/notch",
        author: "octocat",
        isDraft: false,
        createdAt: .now.addingTimeInterval(-7200),
        updatedAt: .now,
        ci: .success,
        review: .approved,
        hasConflict: false,
        othersCommentIDs: [],
        othersReviews: [],
        headOID: "",
        commitCount: 1,
        approvers: ["octocat"],
        changeRequesters: [],
        reviewRequest: .direct,
        failedChecks: []
    )
}
