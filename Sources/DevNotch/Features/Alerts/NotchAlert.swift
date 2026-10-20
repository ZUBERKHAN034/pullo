import SwiftUI

struct NotchAlert: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let tint: Color
    let headline: String
    let detail: String
    var url: URL?
    var pr: PullRequest?
    var actor: String?
    var actorAvatar: URL?
    var account: String?
    var stack: [NotchAlert] = []
    var priority = 0
    var note: String?

    var reference: String? { pr.map { "\($0.repoName) #\($0.number)" } }

    static func summary(of alerts: [NotchAlert], note: String? = nil) -> NotchAlert {
        let sorted = alerts.enumerated()
            .sorted { $0.element.priority != $1.element.priority ? $0.element.priority > $1.element.priority : $0.offset < $1.offset }
            .map(\.element)
        return NotchAlert(
            symbol: "square.stack.3d.up.fill",
            tint: .white,
            headline: String(localized: "\(alerts.count) updates"),
            detail: alerts.map(\.headline).joined(separator: " · "),
            account: Set(alerts.map(\.account)).count == 1 ? alerts.first?.account : nil,
            stack: sorted,
            note: note
        )
    }
}
