import Foundation

/// What a PR looked like the last time you opened it.
struct ReadBaseline: Codable, Equatable {
    var commentIDs: Set<String>
    var reviewIDs: Set<String>
    var headOID: String
    var commitCount: Int
    var ci: CIState?
    var review: ReviewDecision?
    /// Showed up after the account was already being tracked, and you haven't opened it yet.
    var isNew = false

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

/// Tracks what changed on each PR since you last opened it.
@MainActor
final class ReadTracker: ObservableObject {
    @Published private(set) var baselines: [String: ReadBaseline] = [:]

    private var knownAccounts: Set<String> = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "readBaselines"),
           let saved = try? JSONDecoder().decode([String: ReadBaseline].self, from: data) {
            baselines = saved
        }
        knownAccounts = Set(defaults.stringArray(forKey: "readKnownAccounts") ?? [])
    }

    /// The first sync of an account starts everything as read, so a fresh install doesn't light up every PR.
    func sync(account: String, prs: [PullRequest]) {
        let firstSync = !knownAccounts.contains(account)
        var updated = baselines.filter { !$0.key.hasPrefix("\(account)|") }
        for pr in prs {
            let key = Self.key(pr)
            updated[key] = baselines[key] ?? ReadBaseline(pr, isNew: !firstSync)
        }
        let newAccount = knownAccounts.insert(account).inserted
        guard updated != baselines || newAccount else { return }
        baselines = updated
        save()
    }

    func reasons(for pr: PullRequest) -> [String] {
        guard let base = baselines[Self.key(pr)] else { return [] }
        if base.isNew { return [pr.author == pr.account ? "New PR" : "New review request"] }

        var reasons: [String] = []
        let newComments = Set(pr.othersCommentIDs).subtracting(base.commentIDs).count
        if newComments > 0 { reasons.append(newComments == 1 ? "1 new comment" : "\(newComments) new comments") }

        let reviewers = pr.othersReviews.filter { !base.reviewIDs.contains($0.id) }.map(\.author)
        let uniqueReviewers = reviewers.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        if let first = uniqueReviewers.first {
            reasons.append(uniqueReviewers.count == 1 ? "\(first) reviewed" : "\(uniqueReviewers.count) people reviewed")
        }

        if pr.review != base.review {
            if pr.review == .approved { reasons.append("Approved") }
            if pr.review == .changesRequested { reasons.append("Changes requested") }
        }
        if pr.ci != base.ci {
            if pr.ci == .failure { reasons.append("CI failed") }
            if pr.ci == .success { reasons.append("CI passed") }
        }
        // On your own PRs the commits are yours, so only other people's pushes are news.
        if pr.author != pr.account, pr.headOID != base.headOID {
            let added = pr.commitCount - base.commitCount
            reasons.append(added > 0 ? (added == 1 ? "1 new commit" : "\(added) new commits") : "force-push")
        }
        return reasons
    }

    func isUnread(_ pr: PullRequest) -> Bool {
        !reasons(for: pr).isEmpty
    }

    func markRead(_ prs: [PullRequest]) {
        var updated = baselines
        for pr in prs { updated[Self.key(pr)] = ReadBaseline(pr) }
        guard updated != baselines else { return }
        baselines = updated
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(baselines) { defaults.set(data, forKey: "readBaselines") }
        defaults.set(Array(knownAccounts), forKey: "readKnownAccounts")
    }

    private static func key(_ pr: PullRequest) -> String {
        "\(pr.account)|\(pr.id)"
    }
}
