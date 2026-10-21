import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ReadTracker {
    private(set) var baselines: [String: ReadBaseline] = [:]

    private var knownAccounts: Set<String> = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(for: .readBaselines) {
            do {
                baselines = try JSONDecoder().decode([String: ReadBaseline].self, from: data)
            } catch {
                Logger.store.error("Saved read state is unreadable, starting over: \(error.localizedDescription, privacy: .public)")
            }
        }
        knownAccounts = Set(defaults.stringArray(for: .readKnownAccounts) ?? [])
    }

    func sync(account: String, prs: [PullRequest]) {
        let firstSync = !knownAccounts.contains(account)
        var updated = baselines.filter { !$0.key.hasPrefix("\(account)|") }
        for pr in prs {
            let key = Self.key(pr)
            updated[key] = baselines[key] ?? ReadBaseline(pr, isNew: !firstSync && pr.author != account)
        }
        let newAccount = knownAccounts.insert(account).inserted
        guard updated != baselines || newAccount else { return }
        baselines = updated
        save()
    }

    func changes(for pr: PullRequest) -> [ReadChange] {
        guard let base = baselines[Self.key(pr)] else { return [] }
        if base.isNew { return [.newReviewRequest] }

        var changes: [ReadChange] = []
        let newComments = Set(pr.othersCommentIDs).subtracting(base.commentIDs).count
        if newComments > 0 { changes.append(.comments(newComments)) }

        let reviewers = pr.othersReviews.filter { !base.reviewIDs.contains($0.id) }.map { pr.displayLogin($0.author) }
        let uniqueReviewers = reviewers.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        if !uniqueReviewers.isEmpty { changes.append(.reviewed(by: uniqueReviewers)) }

        if pr.review != base.review {
            if pr.review == .approved { changes.append(.approved) }
            if pr.review == .changesRequested { changes.append(.changesRequested) }
        }
        if pr.ci != base.ci {
            if pr.ci == .failure { changes.append(.ciFailed) }
            if pr.ci == .success { changes.append(.ciPassed) }
        }
        if pr.author != pr.account, pr.headOID != base.headOID {
            let added = pr.commitCount - base.commitCount
            changes.append(added > 0 ? .commits(added) : .forcePush)
        }
        return changes
    }

    func isUnread(_ pr: PullRequest) -> Bool {
        !changes(for: pr).isEmpty
    }

    func forget(account: String) {
        baselines = baselines.filter { !$0.key.hasPrefix("\(account)|") }
        knownAccounts.remove(account)
        save()
    }

    func markRead(_ prs: [PullRequest]) {
        var updated = baselines
        for pr in prs { updated[Self.key(pr)] = ReadBaseline(pr) }
        guard updated != baselines else { return }
        baselines = updated
        save()
    }

    private func save() {
        do {
            try defaults.set(JSONEncoder().encode(baselines), for: .readBaselines)
        } catch {
            Logger.store.error("Saving read state failed: \(error.localizedDescription, privacy: .public)")
        }
        defaults.set(Array(knownAccounts), for: .readKnownAccounts)
    }

    private static func key(_ pr: PullRequest) -> String {
        "\(pr.account)|\(pr.id)"
    }
}
