@testable import Pullo
import Testing

extension NotchBehavior {
    @MainActor
    struct FilterTabsTests {
        private let api = SavedFilter(name: "API", query: "repo:acme/acme-api")

        @Test func everyAccountStartsWithMyPRsAndToReview() async {
            let h = await NotchHarness(mine: [.make(id: "PR_1")], review: [.make(id: "PR_2", author: "ana")])
            #expect(h.list.tabs.map(h.list.title(of:)) == ["My PRs", "To review"])
            #expect(h.list.visiblePRs.map(\.id) == ["PR_1"])
            h.list.selectTab(by: 1)
            #expect(h.list.preset(of: h.list.tab) == .review)
            #expect(h.list.visiblePRs.map(\.id) == ["PR_2"])
        }

        @Test func aFilterShowsWhatItsSearchFound() async {
            let h = await NotchHarness(
                mine: [.make(id: "PR_1", repo: "acme/acme-api"), .make(id: "PR_2", repo: "acme/web")],
                review: [.make(id: "PR_3", repo: "acme/acme-api", author: "ana")]
            )
            h.accounts.setFilters([api], for: "me")
            await h.store.refresh()
            #expect(h.list.title(of: h.list.tab) == "API")
            #expect(h.list.visiblePRs.map(\.id) == ["PR_1", "PR_3"])
        }

        @Test func editingADefaultTabTurnsItIntoASearch() async {
            let h = await NotchHarness(mine: [.make(id: "PR_1", repo: "acme/acme-api"), .make(id: "PR_2", repo: "acme/web")])
            var mine = h.accounts.filters(for: "me")[0]
            mine.query = "author:@me repo:acme/acme-api"
            h.accounts.setFilters([mine], for: "me")
            await h.store.refresh()
            #expect(!mine.usesBuiltInSearch)
            #expect(h.list.visiblePRs.map(\.id) == ["PR_1"])
        }

        @Test func rowsKnowWhichPRsAreYours() {
            let tab = PRTab.filter(api.id)
            #expect(tab.rowKind(for: .make(author: "ME")) == .mine)
            #expect(tab.rowKind(for: .make(author: "ana")) == .review)
            #expect(PRTab.review.rowKind(for: .make(author: "me")) == .review)
        }

        @Test func eachAccountHasItsOwnTabs() async {
            let h = await NotchHarness(accounts: ["me", "work"])
            h.accounts.setFilters(h.accounts.filters(for: "me") + [api], for: "me")
            h.list.selectTab(.filter(api.id))
            h.list.selectAccount("work")
            #expect(h.list.tabs.count == 2)
            #expect(h.list.tab == h.list.tabs[0])
        }

        @Test func removingTheOpenTabFallsBackToTheFirst() async {
            let h = await NotchHarness()
            let defaults = h.accounts.filters(for: "me")
            h.accounts.setFilters(defaults + [api], for: "me")
            h.list.selectTab(.filter(api.id))
            h.accounts.setFilters(defaults, for: "me")
            #expect(h.list.tab == .filter(defaults[0].id))
        }

        @Test func searchLooksInEveryTab() async {
            let h = await NotchHarness(
                mine: [.make(id: "PR_1", title: "fix: login")],
                review: [.make(id: "PR_2", title: "fix: logout", author: "ana")]
            )
            h.accounts.setFilters([api], for: "me")
            h.list.startSearch()
            h.list.searchQuery = "fix"
            #expect(Set(h.list.visiblePRs.map(\.id)) == ["PR_1", "PR_2"])
        }

        @Test func changingTabsAsksForAFreshLoad() async {
            let h = await NotchHarness()
            var changed: [String] = []
            h.accounts.onFiltersChanged = { changed.append($0.login) }
            h.accounts.setFilters([api], for: "me")
            h.accounts.setFilters([api], for: "me")
            #expect(changed == ["me"])
            #expect(AccountStore(defaults: h.defaults).filters(for: "me") == [api])
        }
    }
}
