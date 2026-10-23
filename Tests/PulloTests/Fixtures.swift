import Foundation
@testable import Pullo

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
        createdAt: Date = Date(timeIntervalSince1970: 0),
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
            createdAt: createdAt,
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
    private static let folder = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Preferences")
    private static let sweep: Void = {
        let stale = Date.now.addingTimeInterval(-10 * 60)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ??
            []
        for file in files where file.lastPathComponent.hasPrefix("PulloTests.") {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .now
            if modified < stale { try? FileManager.default.removeItem(at: file) }
        }
    }()

    private let suite = "PulloTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        Self.sweep
        guard let defaults = UserDefaults(suiteName: suite) else { preconditionFailure("No defaults suite \(suite)") }
        self.defaults = defaults
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: Self.folder.appending(path: "\(suite).plist"))
    }
}

struct FakeCLI: GitHubCLI {
    var installed = true
    var logins: [String] = []
    var tokens: [String: String] = [:]

    func isInstalled() async -> Bool { installed }
    func users() async -> [String] { logins }

    func token(for user: String) async throws -> String {
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
