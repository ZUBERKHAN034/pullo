import SwiftUI

/// "My PRs" and "To review" with their counts, the filter, and "mark all read" when the tab has updates.
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
            SearchTrigger(action: model.startSearch)
            if unreadCount(in: model.tab) > 0 {
                IconButton(symbol: "checkmark.circle", help: "Mark all as read", action: model.markAllRead)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
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

    /// Turns blue when something in the tab changed, instead of a separate dot.
    private func count(for tab: PRTab, selected: Bool) -> some View {
        let total = model.prs(in: tab).count
        let unread = unreadCount(in: tab)
        let loaded = store.snapshots[model.currentLogin ?? ""] != nil
        return Text(loaded ? "\(total)" : "–")
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(unread > 0 ? Color.unread : .white.opacity(selected ? 0.9 : 0.6))
            .contentTransition(.numericText())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(unread > 0 ? Color.unread.opacity(0.18) : .white.opacity(selected ? 0.16 : 0.08)))
    }

    private func unreadCount(in tab: PRTab) -> Int {
        model.prs(in: tab).filter(tracker.isUnread).count
    }
}
