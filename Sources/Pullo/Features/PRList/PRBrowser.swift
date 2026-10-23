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
            if list.isLoaded, let (login, problem) = list.problem(worthShowingAt: .now) {
                ErrorBanner(problem: problem, account: list.showsAccounts ? login : nil, updated: store.updatedAt[login]) {
                    if problem.opensAccounts {
                        notch.onOpenSettings?(.accounts)
                    } else {
                        Task { await store.refresh() }
                    }
                }
            }
            content
            if list.keyboardMode {
                KeyboardHints(context: .pullRequests(searching: list.isSearching))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !list.isLoaded, let (_, problem) = list.problem() {
            ProblemMessage(problem: problem) { await store.refresh() }
        } else if !list.isLoaded {
            LoadingView()
        } else if list.isSearching {
            searchResults
        } else if let error = list.filterError(in: list.tab) {
            MessageView(
                symbol: "exclamationmark.triangle",
                title: String(localized: "GitHub couldn't run this search"),
                detail: error,
                actionTitle: "Edit tab"
            ) {
                notch.onOpenSettings?(.tabs)
            }
            .id(list.tab)
        } else if list.visiblePRs.isEmpty {
            emptyTab
                .id(list.tab)
        } else {
            PRList(sections: tabSections)
                .id(list.tab)
        }
    }

    private var emptyTab: MessageView {
        switch list.preset(of: list.tab) {
        case .mine:
            MessageView(
                symbol: "tray",
                title: String(localized: "No open PRs"),
                detail: String(localized: "PRs you open will show up here.")
            )
        case .review:
            MessageView(
                symbol: "checkmark.circle",
                title: String(localized: "Nothing to review"),
                detail: String(localized: "No one is waiting on you.")
            )
        case nil:
            MessageView(
                symbol: "line.3.horizontal.decrease.circle",
                title: String(localized: "No matching PRs"),
                detail: String(localized: "Nothing open matches \"\(list.title(of: list.tab))\" right now.")
            )
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = list.visiblePRs
        if list.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            MessageView(
                symbol: "magnifyingglass",
                title: String(localized: "Search pull requests"),
                detail: String(localized: "Title, repo, #number, branch or author. Searches every tab.")
            )
        } else if results.isEmpty {
            MessageView(
                symbol: "questionmark.circle",
                title: String(localized: "No results"),
                detail: String(localized: "No PR matches \"\(list.searchQuery)\".")
            )
        } else {
            PRList(sections: searchSections(results))
        }
    }

    private func searchSections(_ results: [PullRequest]) -> [PRSection] {
        var placed = Set<String>()
        let sections = list.tabs.map { tab in
            let ids = Set(list.prs(in: tab).map(\.id))
            let prs = results.filter { ids.contains($0.id) && placed.insert($0.id).inserted }
            return PRSection(title: list.title(of: tab), kind: tab, prs: prs)
        }
        let rest = results.filter { !placed.contains($0.id) }
        return (sections + [PRSection(title: String(localized: "Other"), kind: nil, prs: rest)]).filter { !$0.prs.isEmpty }
    }

    private var tabSections: [PRSection] {
        let prs = list.visiblePRs
        guard list.preset(of: list.tab) == .review else { return [PRSection(title: nil, kind: list.tab, prs: prs)] }
        return [
            PRSection(title: String(localized: "For you"), kind: .review, prs: prs.filter(\.isDirectRequest)),
            PRSection(title: String(localized: "Via team"), kind: .review, prs: prs.filter { !$0.isDirectRequest }),
        ].filter { !$0.prs.isEmpty }
    }
}
