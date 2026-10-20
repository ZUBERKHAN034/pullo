import SwiftUI

struct PRBrowser: View {
    @Environment(PRListModel.self) private var list
    @Environment(NotchInteraction.self) private var notch
    @Environment(PRStore.self) private var store

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if list.isSearching {
                    SearchBar()
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    PRTabsBar()
                        .transition(.opacity)
                }
            }
            if let login = list.currentLogin, store.snapshots[login] != nil, store.errors[login] != nil {
                ErrorBanner(message: String(localized: "Couldn't refresh @\(login)")) { notch.onOpenSettings?(.accounts) }
            }
            content
            if list.keyboardMode {
                KeyboardHints(searching: list.isSearching)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let login = list.currentLogin ?? ""
        let loaded = store.snapshots[login] != nil
        if !loaded, let error = store.errors[login] {
            MessageView(symbol: "key.slash", title: String(localized: "Can't reach GitHub"), detail: error) {
                Task { await store.refresh() }
            }
        } else if !loaded {
            LoadingView()
        } else if list.isSearching {
            searchResults
        } else if list.visiblePRs.isEmpty {
            MessageView(
                symbol: list.tab == .mine ? "tray" : "checkmark.circle",
                title: list.tab == .mine ? String(localized: "No open PRs") : String(localized: "Nothing to review"),
                detail: list
                    .tab == .mine ? String(localized: "PRs you open will show up here.") : String(localized: "No one is waiting on you.")
            )
            .id("\(login)|\(list.tab)")
        } else {
            PRList(sections: tabSections)
                .id("\(login)|\(list.tab)")
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = list.visiblePRs
        if list.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            MessageView(
                symbol: "magnifyingglass",
                title: String(localized: "Search @\(list.currentLogin ?? "")'s PRs"),
                detail: String(localized: "Title, repo, #number, branch or author. Searches both tabs.")
            )
        } else if results.isEmpty {
            MessageView(
                symbol: "questionmark.circle",
                title: String(localized: "No results"),
                detail: String(localized: "No PR matches \"\(list.searchQuery)\".")
            )
        } else {
            let mineIDs = Set(list.prs(in: .mine).map(\.id))
            PRList(
                sections: [
                    PRSection(title: PRTab.mine.title, kind: .mine, prs: results.filter { mineIDs.contains($0.id) }),
                    PRSection(title: PRTab.review.title, kind: .review, prs: results.filter { !mineIDs.contains($0.id) }),
                ].filter { !$0.prs.isEmpty }
            )
        }
    }

    private var tabSections: [PRSection] {
        let prs = list.visiblePRs
        guard list.tab == .review else { return [PRSection(title: nil, kind: .mine, prs: prs)] }
        return [
            PRSection(title: String(localized: "For you"), kind: .review, prs: prs.filter(\.isDirectRequest)),
            PRSection(title: String(localized: "Via team"), kind: .review, prs: prs.filter { !$0.isDirectRequest }),
        ].filter { !$0.prs.isEmpty }
    }
}
