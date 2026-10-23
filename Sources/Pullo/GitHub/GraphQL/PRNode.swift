import Foundation

struct PRNode: Decodable {
    struct Login: Decodable {
        let login: String
        let avatarUrl: URL?
    }
    struct Actor: Decodable {
        let __typename: String
        let login: String
        let avatarUrl: URL?
    }
    struct Activities: Decodable {
        struct Node: Decodable {
            let id: String
            let author: Actor?
        }
        let nodes: [Node]
    }
    struct Repo: Decodable {
        let nameWithOwner: String
    }
    struct Count: Decodable { let totalCount: Int }
    struct Reviews: Decodable {
        struct Review: Decodable { let state: String; let author: Login? }
        let nodes: [Review]
    }
    struct ReviewRequests: Decodable {
        struct Node: Decodable {
            struct Reviewer: Decodable {
                let __typename: String
                let login: String?
                let name: String?
            }
            let requestedReviewer: Reviewer?
        }
        let nodes: [Node]
    }
    struct Commits: Decodable {
        struct Node: Decodable {
            struct Commit: Decodable {
                struct Rollup: Decodable {
                    struct Contexts: Decodable {
                        struct Context: Decodable {
                            let name: String?
                            let conclusion: String?
                            let detailsUrl: URL?
                            let context: String?
                            let state: String?
                            let targetUrl: URL?
                        }
                        let totalCount: Int?
                        let nodes: [Context]
                    }
                    let state: String
                    let contexts: Contexts?
                }
                let statusCheckRollup: Rollup?
            }
            let commit: Commit
        }
        let nodes: [Node]
    }

    let id: String
    let number: Int
    let title: String
    let url: URL
    let isDraft: Bool
    let createdAt: Date
    let updatedAt: Date
    let reviewDecision: String?
    let mergeable: String?
    let headRefName: String
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?
    let repository: Repo
    let author: Login?
    let comments: Activities
    let reviews: Activities
    let headRefOid: String
    let commitCount: Count
    let latestReviews: Reviews
    let reviewRequests: ReviewRequests
    let commits: Commits

    func pullRequest(account: String) -> PullRequest {
        let reviewers = { (state: String) in
            latestReviews.nodes.filter { $0.state == state }.compactMap { $0.author?.login }
        }
        let requested = reviewRequests.nodes.compactMap(\.requestedReviewer)
        let isDirect = requested.contains {
            $0.__typename == "User" && $0.login?.caseInsensitiveCompare(account) == .orderedSame
        }
        let teams = requested.filter { $0.__typename == "Team" }.compactMap(\.name)
        let rollup = commits.nodes.last?.commit.statusCheckRollup
        let failedConclusions: Set = ["FAILURE", "TIMED_OUT", "STARTUP_FAILURE", "ACTION_REQUIRED", "ERROR"]
        let failedChecks = (rollup?.contexts?.nodes ?? []).compactMap { context -> FailedCheck? in
            guard let outcome = context.conclusion ?? context.state, failedConclusions.contains(outcome) else { return nil }
            return FailedCheck(
                name: context.name ?? context.context ?? "Check",
                url: [context.detailsUrl, context.targetUrl].compactMap(\.self).first(where: \.isWeb)
            )
        }

        return PullRequest(
            id: id,
            account: account,
            number: number,
            title: title,
            url: url,
            repo: repository.nameWithOwner,
            branch: headRefName,
            author: author?.login ?? "ghost",
            isDraft: isDraft,
            createdAt: createdAt,
            updatedAt: updatedAt,
            ci: CIState(rollup: rollup?.state),
            review: ReviewDecision(raw: reviewDecision),
            hasConflict: mergeable == "CONFLICTING",
            othersComments: othersActivity(comments, account: account),
            othersReviews: othersActivity(reviews, account: account),
            headOID: headRefOid,
            commitCount: commitCount.totalCount,
            approvers: reviewers("APPROVED"),
            changeRequesters: reviewers("CHANGES_REQUESTED"),
            reviewRequest: isDirect ? .direct : .team(teams),
            failedChecks: failedChecks,
            avatars: avatars,
            size: size,
            checks: rollup?.contexts.flatMap(checkProgress)
        )
    }

    private func checkProgress(_ contexts: Commits.Node.Commit.Rollup.Contexts) -> CheckProgress? {
        let unfinished: Set = ["PENDING", "EXPECTED"]
        let done = contexts.nodes.count { context in
            if let conclusion = context.conclusion { return !conclusion.isEmpty }
            if let state = context.state { return !unfinished.contains(state) }
            return false
        }
        let total = max(contexts.totalCount ?? contexts.nodes.count, contexts.nodes.count)
        return total > 0 ? CheckProgress(done: done, total: total) : nil
    }

    private var size: PRSize? {
        guard let additions, let deletions, let changedFiles else { return nil }
        return PRSize(additions: additions, deletions: deletions, changedFiles: changedFiles)
    }

    private var avatars: [String: URL] {
        var avatars: [String: URL] = [:]
        let people = [author.map { ($0.login, $0.avatarUrl) }]
            + (comments.nodes + reviews.nodes).map { node in node.author.map { ($0.login, $0.avatarUrl) } }
            + latestReviews.nodes.map { review in review.author.map { ($0.login, $0.avatarUrl) } }
        for case (let login, let url?)? in people { avatars[login] = url }
        return avatars
    }
}

private func othersActivity(_ activities: PRNode.Activities, account: String) -> [Activity] {
    activities.nodes.compactMap { node in
        guard let author = node.author, author.__typename != "Bot",
              author.login.caseInsensitiveCompare(account) != .orderedSame
        else { return nil }
        return Activity(id: node.id, author: author.login)
    }
}
