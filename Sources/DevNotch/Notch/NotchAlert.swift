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
    /// Alerts folded into this one when several arrive together.
    var stack: [NotchAlert] = []

    static func summary(of alerts: [NotchAlert]) -> NotchAlert {
        NotchAlert(
            symbol: "square.stack.3d.up.fill",
            tint: .white,
            headline: "\(alerts.count) updates",
            detail: alerts.map(\.headline).joined(separator: " · "),
            account: Set(alerts.map(\.account)).count == 1 ? alerts.first?.account : nil,
            stack: alerts
        )
    }
}
