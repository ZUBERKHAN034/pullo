import Foundation

extension PullRequest {
    static let sample = PullRequest(
        id: "sample",
        account: "octocat",
        number: 42,
        title: "feat: show PRs in the notch",
        url: .github,
        repo: "jrdan/devnotch",
        branch: "feat/notch",
        author: "octocat",
        isDraft: false,
        createdAt: .now.addingTimeInterval(-7200),
        updatedAt: .now,
        ci: .success,
        review: .approved,
        hasConflict: false,
        othersComments: [],
        othersReviews: [],
        headOID: "",
        commitCount: 1,
        approvers: ["octocat"],
        changeRequesters: [],
        reviewRequest: .direct,
        failedChecks: []
    )
}
