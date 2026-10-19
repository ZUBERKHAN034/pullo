import SwiftUI

/// The PR list screen: tabs or search on top, then the current account's PRs.
struct PRBrowser: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore
    @ObservedObject var tracker: ReadTracker

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if model.isSearching {
                    SearchBar(model: model)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    PRTabsBar(model: model, store: store, tracker: tracker)
                        .transition(.opacity)
                }
            }
            if let login = model.currentLogin, store.snapshots[login] != nil, store.errors[login] != nil {
                ErrorBanner(message: "Couldn't refresh @\(login)") { model.show(.accounts) }
            }
            content
            // Only when driving it from the keyboard; pointer users get tooltips instead.
            if model.keyboardMode {
                KeyboardHints(searching: model.isSearching)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let login = model.currentLogin ?? ""
        let loaded = store.snapshots[login] != nil
        if !loaded, let error = store.errors[login] {
            MessageView(symbol: "key.slash", title: "Can't reach GitHub", detail: error) {
                Task { await store.refresh() }
            }
        } else if !loaded {
            LoadingView()
        } else if model.isSearching {
            searchResults
        } else if model.visiblePRs.isEmpty {
            MessageView(
                symbol: model.tab == .mine ? "tray" : "checkmark.circle",
                title: model.tab == .mine ? "No open PRs" : "Nothing to review",
                detail: model.tab == .mine ? "PRs you open will show up here." : "No one is waiting on you."
            )
            .id("\(login)|\(model.tab)")
        } else {
            PRList(sections: tabSections, model: model, tracker: tracker)
                .id("\(login)|\(model.tab)")
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = model.visiblePRs
        if model.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            MessageView(
                symbol: "magnifyingglass",
                title: "Search @\(model.currentLogin ?? "")'s PRs",
                detail: "Title, repo, #number, branch or author. Searches both tabs."
            )
        } else if results.isEmpty {
            MessageView(symbol: "questionmark.circle", title: "No results", detail: "No PR matches \"\(model.searchQuery)\".")
        } else {
            let mineIDs = Set(model.prs(in: .mine).map(\.id))
            PRList(
                sections: [
                    PRSection(title: PRTab.mine.title, kind: .mine, prs: results.filter { mineIDs.contains($0.id) }),
                    PRSection(title: PRTab.review.title, kind: .review, prs: results.filter { !mineIDs.contains($0.id) }),
                ].filter { !$0.prs.isEmpty },
                model: model,
                tracker: tracker
            )
        }
    }

    /// Review requests split into the ones sent to you and the ones sent to a team you're on.
    private var tabSections: [PRSection] {
        let prs = model.visiblePRs
        guard model.tab == .review else { return [PRSection(title: nil, kind: .mine, prs: prs)] }
        return [
            PRSection(title: "For you", kind: .review, prs: prs.filter(\.isDirectRequest)),
            PRSection(title: "Via team", kind: .review, prs: prs.filter { !$0.isDirectRequest }),
        ].filter { !$0.prs.isEmpty }
    }
}
