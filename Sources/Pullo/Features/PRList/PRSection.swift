import SwiftUI

struct PRSection: Identifiable {
    let title: String?
    let kind: PRTab?
    let prs: [PullRequest]

    var id: String { title ?? "all" }
}
