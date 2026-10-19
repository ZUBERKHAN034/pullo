import SwiftUI

/// Anything that drops out of the notch for a few seconds.
struct NotchAlert: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let tint: Color
    let headline: String
    let detail: String
    var url: URL?
    /// The PR it's about, so opening it from the alert marks it read like opening it from the list does.
    var pr: PullRequest?
    /// Shown as a small chip when more than one account is connected.
    var account: String?
    /// Alerts folded into this one when several arrive together, most important first.
    var stack: [NotchAlert] = []
    /// Higher comes first in a stack, so what needs you isn't buried under good news.
    var priority = 0

    /// Short "repo #n" for the PR, when there is one.
    var reference: String? { pr.map { "\($0.repoName) #\($0.number)" } }

    static func summary(of alerts: [NotchAlert]) -> NotchAlert {
        // Stable: equal priorities keep the order they arrived in.
        let sorted = alerts.enumerated()
            .sorted { $0.element.priority != $1.element.priority ? $0.element.priority > $1.element.priority : $0.offset < $1.offset }
            .map(\.element)
        return NotchAlert(
            symbol: "square.stack.3d.up.fill",
            tint: .white,
            headline: "\(alerts.count) updates",
            detail: alerts.map(\.headline).joined(separator: " · "),
            account: Set(alerts.map(\.account)).count == 1 ? alerts.first?.account : nil,
            stack: sorted
        )
    }
}
