import Foundation

/// One account's open PRs at a point in time.
struct Snapshot {
    let mine: [PullRequest]
    let reviewRequests: [PullRequest]
}
