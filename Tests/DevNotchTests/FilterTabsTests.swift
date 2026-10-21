@testable import DevNotch
import Testing

extension NotchBehavior {
    @MainActor
    struct FilterTabsTests {
        private let api = SavedFilter(name: "API", query: "repo:acme/acme-api")

        @Test func aFilterShowsWhatItsSearchFound() async {
            let h = await NotchHarness(
                mine: [.make(id: "PR_1", repo: "acme/acme-api"), .make(id: "PR_2", repo: "acme/web")],
                review: [.make(id: "PR_3", repo: "acme/acme-api", author: "ana")]
            )
            h.accounts.setFilters([api], for: "me")
            await h.store.refresh()
            h.list.selectTab(.filter(api.id))
            #expect(h.list.title(of: h.list.tab) == "API")
            #expect(h.list.visiblePRs.map(\.id) == ["PR_1", "PR_3"])
        }

        @Test func rowsKnowWhichPRsAreYours() {
            let tab = PRTab.filter(api.id)
            #expect(tab.rowKind(for: .make(author: "ME")) == .mine)
            #expect(tab.rowKind(for: .make(author: "ana")) == .review)
            #expect(PRTab.review.rowKind(for: .make(author: "me")) == .review)
        }

        @Test func eachAccountHasItsOwnFilters() async {
            let h = await NotchHarness(accounts: ["me", "work"])
            h.accounts.setFilters([api], for: "me")
            h.list.selectTab(.filter(api.id))
            h.list.selectAccount("work")
            #expect(h.list.tabs == [.mine, .review])
            #expect(h.list.tab == .mine)
        }

        @Test func removingTheOpenFilterFallsBackToMyPRs() async {
            let h = await NotchHarness()
            h.accounts.setFilters([api], for: "me")
            h.list.selectTab(.filter(api.id))
            h.accounts.setFilters([], for: "me")
            #expect(h.list.tab == .mine)
        }

        @Test func changingFiltersAsksForAFreshLoad() async {
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
