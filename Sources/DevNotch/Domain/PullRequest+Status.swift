import Foundation

enum PRStatus: Equatable {
    case conflict, ciFailed, changesRequested, ciRunning, readyToMerge, draft, ciPassed, noChecks

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

    var explanation: String {
        switch self {
        case .conflict: "Conflicts with the base branch"
        case .ciFailed: "Checks failed · click to see which"
        case .changesRequested: "A reviewer requested changes"
        case .ciRunning: "Checks are running"
        case .readyToMerge: "Approved and checks passed · ready to merge"
        case .draft: "Draft, not ready for review"
        case .ciPassed: "Checks passed"
        case .noChecks: "No checks on this PR"
        }
    }
}

extension PullRequest {
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
