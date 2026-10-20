@testable import DevNotch
import Foundation

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
        reviewRequest: ReviewRequest = .direct,
        updatedAt: Date = Date(timeIntervalSince1970: 0),
        checks: CheckProgress? = nil
    ) -> PullRequest {
        PullRequest(
            id: id,
            account: account,
            number: number,
            title: title,
            url: .pullRequest(repo: repo, number: number),
            repo: repo,
            branch: branch,
            author: author,
            isDraft: draft,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: updatedAt,
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
            failedChecks: [],
            checks: checks
        )
    }
}

final class ScratchDefaults {
    private let suite = "DevNotchTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        guard let defaults = UserDefaults(suiteName: suite) else { preconditionFailure("No defaults suite \(suite)") }
        self.defaults = defaults
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
        let file = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Preferences/\(suite).plist")
        try? FileManager.default.removeItem(at: file)
    }
}

struct FakeCLI: GitHubCLI {
    var installed = true
    var logins: [String] = []
    var tokens: [String: String] = [:]

    var isInstalled: Bool { installed }
    func users() -> [String] { logins }

    func token(for user: String) throws -> String {
        guard let token = tokens[user] else { throw GitHubError.noToken }
        return token
    }
}

extension AccountStore {
    convenience init(defaults: UserDefaults) {
        let cli = FakeCLI()
        self.init(defaults: defaults, cli: cli, tokens: TokenProvider(cli: cli))
    }
}
