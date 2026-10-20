import SwiftUI

struct PRRow: View {
    let pr: PullRequest
    let kind: PRTab
    let selected: Bool
    /// What changed since you last opened it; empty means read.
    let unreadReasons: [String]
    @ObservedObject var model: NotchViewModel

    @State private var hovering = false
    @State private var showingChecks = false

    private var isUnread: Bool { !unreadReasons.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                leading
                    .frame(width: 18)
                    // Its hover hint opens over the title, so it has to draw above it.
                    .zIndex(1)
                VStack(alignment: .leading, spacing: 2) {
                    // Unread shows as a bolder title, what changed on the line below, and a blue dot by the age.
                    Text(pr.title)
                        .font(.system(size: 12.5, weight: isUnread ? .semibold : .medium))
                        .foregroundStyle(.white.opacity(isUnread ? 1 : 0.88))
                        .lineLimit(1)
                    subtitle
                }
                Spacer(minLength: 8)
                badges
            }
            if showingChecks {
                FailedChecksList(pr: pr, model: model)
                    .padding(.leading, 28)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.white.opacity(hovering || selected ? 0.08 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(.white.opacity(selected ? 0.14 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
        .animation(Motion.hover, value: selected)
        .animation(Motion.navigate, value: isUnread)
        .onTapGesture { model.open(pr) }
    }

    private var statuses: [PRStatus] { pr.statuses(mine: kind == .mine) }

    /// The most urgent state; with failing CI it also opens the list of failed checks.
    @ViewBuilder
    private var leading: some View {
        let icon = StatusIcon(status: statuses.first ?? .noChecks)
        if pr.ci == .failure {
            Button {
                withAnimation(Motion.navigate) { showingChecks.toggle() }
            } label: {
                icon
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(showingChecks ? 0.12 : 0)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .hint(statuses.first?.explanation ?? "")
        } else {
            icon.hint(statuses.first?.explanation ?? "")
        }
    }

    /// Everything about the PR in one gray line: what changed if it's unread, then where it lives and its states.
    private var subtitle: some View {
        Group {
            if isUnread {
                Text(unreadReasons.joined(separator: " · ")).foregroundColor(.white.opacity(0.82))
                    + Text(verbatim: "  ·  " + details.joined(separator: " · ")).foregroundColor(.secondaryText)
            } else {
                Text(details.joined(separator: " · ")).foregroundColor(.secondaryText)
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
    }

    /// The branch stays out of the row; it's in the tooltip and one keystroke away with "c".
    private var details: [String] {
        var parts = ["\(pr.repoName) #\(pr.number)"]
        if kind == .review {
            parts.append("by \(pr.displayLogin(pr.author))")
            if case .team(let teams) = pr.reviewRequest, let team = teams.first {
                parts.append("via \(teams.count > 1 ? "\(team) +\(teams.count - 1)" : team)")
            }
        }
        return parts + statuses.compactMap(\.label)
    }

    private var badges: some View {
        HStack(spacing: 8) {
            if hovering || selected, isUnread {
                IconButton(symbol: "envelope.open", help: "Mark as read · r") { model.markRead(pr) }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            HStack(spacing: 6) {
                if isUnread {
                    Circle().fill(Color.unread).frame(width: 6, height: 6)
                        .transition(.scale.combined(with: .opacity))
                }
                // Your PRs are sorted by activity, review requests by how long they've waited; the age follows suit.
                Text(ageDate.shortAge)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.secondaryText)
                    .hint(ageHelp, edge: .leading)
            }
            .frame(minWidth: 34, alignment: .trailing)
        }
    }

    private var ageDate: Date { kind == .mine ? pr.updatedAt : pr.createdAt }

    private var ageHelp: String {
        guard kind == .review else { return "Updated \(ageDate.shortAge) ago" }
        return pr.isDirectRequest ? "Waiting on your review for \(ageDate.shortAge)" : "Opened \(ageDate.shortAge) ago"
    }
}
