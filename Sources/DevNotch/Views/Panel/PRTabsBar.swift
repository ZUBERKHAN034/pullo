import SwiftUI

/// "My PRs" and "To review", with counts, unread dots, and "mark read" or the last update on the right.
struct PRTabsBar: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore
    @ObservedObject var tracker: ReadTracker
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PRTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()
            if unreadCount(in: model.tab) > 0 {
                Button(action: model.markAllRead) {
                    Label("Mark all read", systemImage: "checkmark.circle")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.unread)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.unread.opacity(0.14)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                TimelineView(.periodic(from: .now, by: 15)) { _ in
                    Text(updatedLabel)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .animation(Motion.navigate, value: unreadCount(in: model.tab))
    }

    private func tabButton(_ tab: PRTab) -> some View {
        let selected = model.tab == tab
        return Button {
            model.selectTab(tab)
        } label: {
            HStack(spacing: 6) {
                Text(tab.title)
                count(for: tab, selected: selected)
                if unreadCount(in: tab) > 0 {
                    Circle().fill(Color.unread).frame(width: 6, height: 6)
                        .help("\(unreadCount(in: tab)) with updates")
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(selected ? 1 : 0.45))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                if selected {
                    Capsule()
                        .fill(.white.opacity(0.1))
                        .matchedGeometryEffect(id: "tab", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Review requests count only the direct ones up front; team requests trail behind, dimmer.
    private func count(for tab: PRTab, selected: Bool) -> some View {
        let prs = model.prs(in: tab)
        let teamCount = tab == .review ? prs.filter { !$0.isDirectRequest }.count : 0
        let loaded = store.snapshots[model.currentLogin ?? ""] != nil
        return HStack(spacing: 3) {
            Text(loaded ? "\(prs.count - teamCount)" : "–")
            if teamCount > 0 {
                Text("+\(teamCount)").foregroundStyle(.white.opacity(0.4))
            }
        }
        .font(.system(size: 10.5, weight: .bold, design: .rounded))
        .contentTransition(.numericText())
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(Capsule().fill(.white.opacity(selected ? 0.16 : 0.08)))
        .help(tab == .review ? "Requests to you, + requests to your teams" : "")
    }

    private func unreadCount(in tab: PRTab) -> Int {
        model.prs(in: tab).filter(tracker.isUnread).count
    }

    private var updatedLabel: String {
        guard let updated = store.lastUpdated else { return "loading…" }
        let age = updated.shortAge
        return age == "now" ? "updated just now" : "updated \(age) ago"
    }
}
