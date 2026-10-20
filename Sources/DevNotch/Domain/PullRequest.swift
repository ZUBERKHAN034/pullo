import Foundation

enum CIState: String, Codable, Equatable {
    case success, failure, pending

    init?(rollup: String?) {
        switch rollup {
        case "SUCCESS": self = .success
        case "FAILURE", "ERROR": self = .failure
        case "PENDING", "EXPECTED": self = .pending
        default: return nil
        }
    }
}

enum ReviewDecision: String, Codable, Equatable {
    case approved, changesRequested, reviewRequired

    init?(raw: String?) {
        switch raw {
        case "APPROVED": self = .approved
        case "CHANGES_REQUESTED": self = .changesRequested
        case "REVIEW_REQUIRED": self = .reviewRequired
        default: return nil
        }
    }
}

struct FailedCheck: Identifiable, Equatable {
    let name: String
    let url: URL?

    var id: String { "\(name)|\(url?.absoluteString ?? "")" }
}

enum ReviewRequest: Equatable {
    case direct
    case team([String])
}

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

    var isDirectRequest: Bool { reviewRequest == .direct }

    var othersCommentIDs: [String] { othersComments.map(\.id) }

    /// Drops the company suffix GitHub's managed accounts share (`ana_acme` next to your `you_acme`), since
    /// everyone in the list has it.
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

struct Activity: Codable, Equatable {
    let id: String
    let author: String
}
