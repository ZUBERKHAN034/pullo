import Foundation

struct Snapshot {
    let mine: [PullRequest]
    let reviewRequests: [PullRequest]
    var filtered: [SavedFilter.ID: [PullRequest]] = [:]
    var filterErrors: [SavedFilter.ID: String] = [:]
}
