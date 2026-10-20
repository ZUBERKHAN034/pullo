import Foundation

struct LiveCI: Equatable {
    let pr: PullRequest
    let othersRunning: Int
    var finished: CIState?

    var checks: CheckProgress? { pr.checks }

    var wingWidth: CGFloat { othersRunning > 0 ? 66 : 46 }
}
