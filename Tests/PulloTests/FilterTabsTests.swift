import Foundation
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
            h.accounts.setTabs([api])
            await h.store.refresh()
            #expect(h.list.title(of: h.list.tab) == "API")
            #expect(h.list.visiblePRs.map(\.id) == ["PR_1", "PR_3"])
        }

        @Test func editingADefaultTabTurnsItIntoASearch() async {
            let h = await NotchHarness(mine: [.make(id: "PR_1", repo: "acme/acme-api"), .make(id: "PR_2", repo: "acme/web")])
            var mine = h.accounts.tabs[0]
            mine.query = "author:@me repo:acme/acme-api"
            h.accounts.setTabs([mine])
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

        @Test func everyAccountShowsUpInTheSameTab() async {
            let h = await NotchHarness(
                accounts: ["me", "work"],
                mine: [
                    .make(id: "PR_1", account: "me", updatedAt: Date(timeIntervalSince1970: 1)),
                    .make(id: "PR_2", account: "work", updatedAt: Date(timeIntervalSince1970: 2)),
                ]
            )
            #expect(h.list.tabs.count == 2)
            #expect(h.list.visiblePRs.map(\.id) == ["PR_2", "PR_1"])
        }

        @Test func aTabCanStickToOneAccount() async {
            let h = await NotchHarness(
                accounts: ["me", "work"],
                mine: [.make(id: "PR_1", account: "me", repo: "acme/acme-api"), .make(id: "PR_2", account: "work", repo: "acme/acme-api")]
            )
            var workAPI = api
            workAPI.account = "work"
            h.accounts.setTabs([workAPI])
            await h.store.refresh()
            #expect(h.accounts.filters(for: "me").isEmpty)
            #expect(h.list.visiblePRs.map(\.id) == ["PR_2"])
        }

        @Test func aPRBothAccountsSeeShowsUpOnce() async {
            let h = await NotchHarness(
                accounts: ["me", "work"],
                review: [.make(id: "PR_1", account: "me", author: "ana"), .make(id: "PR_1", account: "work", author: "ana")]
            )
            h.list.selectTab(by: 1)
            #expect(h.list.visiblePRs.map { $0.account } == ["me"])
        }

        @Test func tabsSavedPerAccountBecomeOneList() {
            let shared = SavedFilter(name: "API", query: "repo:acme/api")
            let bugs = SavedFilter(name: "Bugs", query: "label:bug")
            var sameAPI = shared
            sameAPI.id = UUID()
            let merged = SavedFilter.merging([
                ("me", SavedFilter.defaults + [shared, bugs]),
                ("work", SavedFilter.defaults + [sameAPI]),
            ])
            #expect(merged.map(\.name) == ["My PRs", "To review", "API", "Bugs"])
            #expect(merged.map(\.account) == [nil, nil, nil, "me"])
        }

        @Test func removingAnAccountDropsItsOwnTabs() async throws {
            let h = await NotchHarness(accounts: ["me", "work"])
            var workAPI = api
            workAPI.account = "work"
            h.accounts.setTabs(h.accounts.tabs + [workAPI])
            try h.accounts.remove(#require(h.accounts.accounts.last))
            #expect(h.accounts.tabs.count == 2)
        }

        @Test func removingTheOpenTabFallsBackToTheFirst() async {
            let h = await NotchHarness()
            let defaults = h.accounts.tabs
            h.accounts.setTabs(defaults + [api])
            h.list.selectTab(.filter(api.id))
            h.accounts.setTabs(defaults)
            #expect(h.list.tab == .filter(defaults[0].id))
        }

        @Test func searchLooksInEveryTab() async {
            let h = await NotchHarness(
                mine: [.make(id: "PR_1", title: "fix: login")],
                review: [.make(id: "PR_2", title: "fix: logout", author: "ana")]
            )
            h.accounts.setTabs([api])
            h.list.startSearch()
            h.list.searchQuery = "fix"
            #expect(Set(h.list.visiblePRs.map(\.id)) == ["PR_1", "PR_2"])
        }

        @Test func changingTabsAsksForAFreshLoad() async {
            let h = await NotchHarness()
            var changes = 0
            h.accounts.onTabsChanged = { changes += 1 }
            h.accounts.setTabs([api])
            h.accounts.setTabs([api])
            #expect(changes == 1)
            #expect(AccountStore(defaults: h.defaults).tabs == [api])
        }
    }
}
