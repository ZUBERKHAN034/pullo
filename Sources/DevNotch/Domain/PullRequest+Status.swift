import Foundation

enum PRStatus: Equatable {
    case conflict, ciFailed, changesRequested, ciRunning, readyToMerge, draft, ciPassed, noChecks

    var label: String? {
        switch self {
        case .conflict: String(localized: "Conflict")
        case .ciFailed: String(localized: "CI failed")
        case .changesRequested: String(localized: "Changes requested")
        case .ciRunning: String(localized: "CI running")
        case .readyToMerge: String(localized: "Ready to merge")
        case .draft: String(localized: "Draft")
        case .ciPassed, .noChecks: nil
        }
    }

    var explanation: String {
        switch self {
        case .conflict: String(localized: "Conflicts with the base branch")
        case .ciFailed: String(localized: "Checks failed · click to see which")
        case .changesRequested: String(localized: "A reviewer requested changes")
        case .ciRunning: String(localized: "Checks are running")
        case .readyToMerge: String(localized: "Approved and checks passed · ready to merge")
        case .draft: String(localized: "Draft, not ready for review")
        case .ciPassed: String(localized: "Checks passed")
        case .noChecks: String(localized: "No checks on this PR")
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
