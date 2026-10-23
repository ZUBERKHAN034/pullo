import Foundation

struct LiveCI: Equatable {
    static let maxNameLength = 14

    let id: String
    let name: String
    let title: String
    let checks: CheckProgress?
    var failing = false
    var othersRunning = 0
    var finished: CIState?
    var label: LiveCILabel = .number

    init(pr: PullRequest, othersRunning: Int = 0, finished: CIState? = nil, label: LiveCILabel = .number) {
        id = pr.id
        name = "#\(pr.number)"
        title = pr.title
        checks = pr.checks
        self.othersRunning = othersRunning
        self.finished = finished
        self.label = label
    }

    init(run: WorkflowRun, othersRunning: Int = 0, finished: CIState? = nil, label: LiveCILabel = .number) {
        id = "run-\(run.id)"
        name = run.pullRequest.map { "#\($0)" } ?? Self.shortened(run.workflow)
        title = "\(run.workflow) · \(run.repoName)"
        checks = run.jobs.flatMap { $0.total > 0 ? CheckProgress(done: $0.done, total: $0.total) : nil }
        failing = (run.jobs?.failed ?? 0) > 0
        self.othersRunning = othersRunning
        self.finished = finished
        self.label = label
    }

    var checksText: String? { checks.map { "\($0.done)/\($0.total)" } }
    var othersText: String? { othersRunning > 0 ? "+\(othersRunning)" : nil }

    var showsNumberBeside: Bool { label == .both }
    var trailingText: String? { label == .number ? name : checksText }

    var wingWidth: CGFloat {
        let leading = 14 + (showsNumberBeside ? 4 + Self.width(of: name) : 0)
        var trailing = trailingText.map(Self.width(of:)) ?? 0
        if let othersText { trailing += 4 + Self.width(of: othersText) + 8 }
        return max(46, max(leading, trailing) + 20)
    }

    private static func width(of text: String) -> CGFloat { CGFloat(text.count) * 7 }

    private static func shortened(_ name: String) -> String {
        name.count > maxNameLength ? String(name.prefix(maxNameLength - 1)) + "…" : name
    }
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
