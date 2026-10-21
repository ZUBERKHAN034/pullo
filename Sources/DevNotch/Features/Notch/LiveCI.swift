import Foundation

struct LiveCI: Equatable {
    let pr: PullRequest
    let othersRunning: Int
    var finished: CIState?
    var label: LiveCILabel = .number

    var checks: CheckProgress? { pr.checks }

    var numberText: String { "#\(pr.number)" }
    var checksText: String? { checks.map { "\($0.done)/\($0.total)" } }
    var othersText: String? { othersRunning > 0 ? "+\(othersRunning)" : nil }

    var showsNumberBeside: Bool { label == .both }
    var trailingText: String? { label == .number ? numberText : checksText }

    var wingWidth: CGFloat {
        let leading = 14 + (showsNumberBeside ? 4 + Self.width(of: numberText) : 0)
        var trailing = trailingText.map(Self.width(of:)) ?? 0
        if let othersText { trailing += 4 + Self.width(of: othersText) + 8 }
        return max(46, max(leading, trailing) + 20)
    }

    private static func width(of text: String) -> CGFloat { CGFloat(text.count) * 7 }
}

enum LiveCILabel: String, CaseIterable {
    case number, checks, both

    var title: String {
        switch self {
        case .number: String(localized: "PR number")
        case .checks: String(localized: "Checks done")
        case .both: String(localized: "Both")
        }
    }
}
