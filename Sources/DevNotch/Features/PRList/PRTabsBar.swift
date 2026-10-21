import SwiftUI

struct PRTabsBar: View {
    @Environment(PRListModel.self) private var list
    @Environment(PRStore.self) private var store
    @Environment(ReadTracker.self) private var tracker
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(list.tabs, id: \.self) { tab in
                            tabButton(tab).id(tab)
                        }
                    }
                }
                .onChange(of: list.tab) { _, tab in
                    withAnimation(Motion.navigate) { proxy.scrollTo(tab) }
                }
            }
            SearchTrigger(action: list.startSearch)
            if unreadCount(in: list.tab) > 0 {
                IconButton(symbol: "envelope.open", help: String(localized: "Mark all as read"), action: list.markAllRead)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(Motion.navigate, value: unreadCount(in: list.tab))
    }

    private func tabButton(_ tab: PRTab) -> some View {
        let selected = list.tab == tab
        return Button {
            list.selectTab(tab)
        } label: {
            HStack(spacing: 6) {
                Text(list.title(of: tab))
                    .lineLimit(1)
                count(for: tab, selected: selected)
            }
            .font(.panel(.label, .semibold))
            .foregroundStyle(selected ? Color.white : .textTertiary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                if selected {
                    Capsule()
                        .fill(.surface)
                        .matchedGeometryEffect(id: "tab", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func count(for tab: PRTab, selected: Bool) -> some View {
        let total = list.prs(in: tab).count
        let unread = unreadCount(in: tab)
        let loaded = store.snapshots[list.currentLogin ?? ""] != nil
        return Text(loaded ? "\(total)" : "–")
            .font(.panel(.caption, .bold, design: .rounded))
            .foregroundStyle(unread > 0 ? Color.unread : selected ? .textStrong : .textSecondary)
            .contentTransition(.numericText())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(unread > 0 ? Color.unread.opacity(0.18) : selected ? .surfaceStrong : .surfaceSubtle))
    }

    private func unreadCount(in tab: PRTab) -> Int {
        list.prs(in: tab).filter(tracker.isUnread).count
    }
}
