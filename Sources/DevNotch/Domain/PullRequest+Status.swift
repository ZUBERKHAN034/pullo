import Foundation

/// The states a PR can be in, most urgent first. The row shows the first one as its icon and names the rest.
enum PRStatus: Equatable {
    case conflict, ciFailed, changesRequested, ciRunning, readyToMerge, draft, ciPassed, noChecks

    /// Passing or absent CI is the normal case, so it gets an icon but no word.
    var label: String? {
        switch self {
        case .conflict: "Conflict"
        case .ciFailed: "CI failed"
        case .changesRequested: "Changes requested"
        case .ciRunning: "CI running"
        case .readyToMerge: "Ready to merge"
        case .draft: "Draft"
        case .ciPassed, .noChecks: nil
        }
    }
}

extension PullRequest {
    /// Review state and readiness only matter on your own PRs; on someone else's, it's their call.
    func statuses(mine: Bool) -> [PRStatus] {
        var statuses: [PRStatus] = []
        if hasConflict { statuses.append(.conflict) }
        if ci == .failure { statuses.append(.ciFailed) }
        if mine, review == .changesRequested { statuses.append(.changesRequested) }
        if ci == .pending { statuses.append(.ciRunning) }
        if mine, isReadyToMerge { statuses.append(.readyToMerge) }
        if isDraft { statuses.append(.draft) }
        if ci == .success { statuses.append(.ciPassed) }
        if ci == nil { statuses.append(.noChecks) }
        return statuses
    }
}
