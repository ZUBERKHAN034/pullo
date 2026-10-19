import SwiftUI

struct PRRow: View {
    let pr: PullRequest
    let kind: PRTab
    let selected: Bool
    /// What changed since you last opened it; empty means read.
    let unreadReasons: [String]
    @ObservedObject var model: NotchViewModel

    @ViewState private var hovering = false
    @ViewState private var showingChecks = false

    private var isUnread: Bool { !unreadReasons.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                leading
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    // Unread shows as a bolder title and the blue line saying what changed.
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
        .help("\(pr.repo) #\(pr.number) · \(pr.branch)")
    }

    @ViewBuilder
    private var leading: some View {
        if let ci = pr.ci {
            if ci == .failure {
                Button {
                    withAnimation(Motion.navigate) { showingChecks.toggle() }
                } label: {
                    CIStatusIcon(state: ci, size: 14)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.red.opacity(showingChecks ? 0.25 : 0)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Show failed checks")
            } else {
                CIStatusIcon(state: ci, size: 14)
            }
        } else {
            Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5).frame(width: 14, height: 14)
                .help("No checks")
        }
    }

    private var subtitle: some View {
        Group {
            if isUnread {
                Text(unreadReasons.joined(separator: " · ")).foregroundColor(.unread)
                    + Text(verbatim: "   \(pr.repoName) #\(pr.number)").foregroundColor(.secondaryText)
            } else {
                Text(subtitleText).foregroundColor(.secondaryText)
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
    }

    /// The branch stays out of the row; it's in the tooltip and one keystroke away with "c".
    private var subtitleText: String {
        let ref = "\(pr.repoName) #\(pr.number)"
        switch kind {
        case .mine:
            return ref
        case .review:
            if case .team(let teams) = pr.reviewRequest, let team = teams.first {
                return "\(ref) · by \(pr.author) · via \(teams.count > 1 ? "\(team) +\(teams.count - 1)" : team)"
            }
            return "\(ref) · by \(pr.author)"
        }
    }

    private var badges: some View {
        HStack(spacing: 6) {
            if hovering || selected {
                HStack(spacing: 0) {
                    if isUnread {
                        IconButton(symbol: "checkmark.circle", help: "Mark as read (r)") { model.markRead(pr) }
                    }
                    IconButton(symbol: "doc.on.doc", help: "Copy branch (c)") { model.copyBranch(pr) }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            if let status { status }
            // Your PRs are sorted by activity, review requests by how long they've waited; the age follows suit.
            Text(ageDate.shortAge)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(ageTint)
                .frame(minWidth: 30, alignment: .trailing)
                .help(ageHelp)
        }
    }

    /// One tag at most, the one that matters most, so the row stays quiet.
    private var status: Tag? {
        if pr.hasConflict { return Tag(text: "Conflict", tint: .orange, symbol: "exclamationmark.triangle.fill") }
        if kind == .mine, pr.review == .changesRequested {
            return Tag(text: "Changes", tint: .red, symbol: "exclamationmark.bubble.fill")
        }
        if pr.isDraft { return Tag(text: "Draft", tint: .gray) }
        if kind == .mine, pr.review == .approved {
            return Tag(text: pr.isReadyToMerge ? "Ready" : "Approved", tint: .green, symbol: "checkmark.seal.fill")
        }
        return nil
    }

    private var ageDate: Date { kind == .mine ? pr.updatedAt : pr.createdAt }

    private var ageHelp: String {
        guard kind == .review else { return "Updated \(ageDate.shortAge) ago" }
        return pr.isDirectRequest ? "Waiting on your review for \(ageDate.shortAge)" : "Opened \(ageDate.shortAge) ago"
    }

    /// Review requests get louder the longer someone has been waiting on you.
    private var ageTint: Color {
        guard kind == .review, pr.isDirectRequest else { return .secondaryText }
        let hours = Date().timeIntervalSince(pr.createdAt) / 3600
        if hours > 48 { return .red }
        if hours > 24 { return .orange }
        return .secondaryText
    }
}
