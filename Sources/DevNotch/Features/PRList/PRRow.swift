import SwiftUI

struct PRRow: View {
    let pr: PullRequest
    let kind: PRTab
    let selected: Bool
    let changes: [ReadChange]
    @ObservedObject var model: NotchViewModel

    @State private var hovering = false
    @State private var showingChecks = false

    private var isUnread: Bool { !changes.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                leading
                    .frame(width: 18)
                    .zIndex(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pr.title)
                        .font(.panel(.title, isUnread ? .semibold : .medium))
                        .foregroundStyle(isUnread ? Color.white : .textStrong)
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
                .fill(hovering || selected ? Color.surfaceSubtle : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(selected ? Color.surfaceStrong : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
        .animation(Motion.hover, value: selected)
        .animation(Motion.navigate, value: isUnread)
        .onTapGesture { model.open(pr) }
    }

    private var statuses: [PRStatus] { pr.statuses(mine: kind == .mine) }

    @ViewBuilder
    private var leading: some View {
        let icon = StatusIcon(status: statuses.first ?? .noChecks)
        if pr.ci == .failure {
            Button {
                withAnimation(Motion.navigate) { showingChecks.toggle() }
            } label: {
                icon
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(showingChecks ? Color.surfaceStrong : .clear))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .hint(statuses.first?.explanation ?? "")
        } else {
            icon.hint(statuses.first?.explanation ?? "")
        }
    }

    private var subtitle: some View {
        Group {
            if isUnread {
                Text(changes.map(\.label).joined(separator: " · ")).foregroundColor(.textStrong)
                    + Text(verbatim: "  ·  " + details.joined(separator: " · ")).foregroundColor(.textSecondary)
            } else {
                Text(details.joined(separator: " · ")).foregroundColor(.textSecondary)
            }
        }
        .font(.panel(.small))
        .lineLimit(1)
    }

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
                    UnreadDot()
                        .transition(.scale.combined(with: .opacity))
                }
                Text(ageDate.shortAge)
                    .font(.panel(.small, .medium).monospacedDigit())
                    .foregroundStyle(.textSecondary)
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
