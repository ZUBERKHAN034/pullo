import Foundation
@testable import Pullo
import Testing

struct SavedFilterTests {
    @Test func searchesOpenPullRequestsByDefault() {
        let filter = SavedFilter(name: "Bugs", query: "  repo:acme/api label:bug ")
        #expect(filter.searchQuery == "is:pr archived:false is:open repo:acme/api label:bug sort:updated-desc")
    }

    @Test func keepsTheStateAndOrderYouPick() {
        let filter = SavedFilter(name: "Shipped", query: "repo:acme/api is:merged sort:created-asc")
        #expect(filter.searchQuery == "is:pr archived:false repo:acme/api is:merged sort:created-asc")
    }

    @Test func lineBreaksInTheSearchAreJustSpaces() {
        let filter = SavedFilter(name: "Bugs", query: "repo:acme/api\n  label:bug")
        #expect(filter.searchQuery == "is:pr archived:false is:open repo:acme/api label:bug sort:updated-desc")
        var mine = SavedFilter.builtIn(.mine)
        mine.query = " author:@me\n"
        #expect(mine.usesBuiltInSearch)
        #expect(!SavedFilter(name: "API", query: "\n").isComplete)
    }

    @Test func needsANameAndAQuery() {
        #expect(!SavedFilter(name: "", query: "repo:acme/api").isComplete)
        #expect(!SavedFilter(name: "API", query: " ").isComplete)
        #expect(SavedFilter(name: "API", query: "repo:acme/api").isComplete)
    }

    @Test func previewsTheSameSearchOnGitHub() throws {
        let url = try #require(SavedFilter(name: "API", query: "repo:acme/api").webURL)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }?.value
        #expect(url.host() == "github.com")
        #expect(query == "is:pr archived:false is:open repo:acme/api sort:updated-desc")
    }

    @MainActor @Test func accountsSavedBeforeTabsGetTheDefaultOnes() {
        let scratch = ScratchDefaults()
        scratch.defaults.set(Data(#"[{ "login": "me", "avatarURL": null }]"#.utf8), for: .accounts)
        #expect(AccountStore(defaults: scratch.defaults).tabs.map(\.preset) == [.mine, .review])
    }

    @Test func defaultTabsReuseTheBuiltInSearches() {
        var mine = SavedFilter.builtIn(.mine)
        #expect(mine.usesBuiltInSearch)
        mine.name = "Mine"
        #expect(mine.usesBuiltInSearch)
        mine.query = "author:@me draft:false"
        #expect(!mine.usesBuiltInSearch)
        #expect(!SavedFilter(name: "Mine", query: "author:@me").usesBuiltInSearch)
    }

    @Test func aSearchNeedsSomethingThatNarrowsIt() {
        #expect(!SavedFilter(name: "Merged", query: "is:merged").isScoped)
        #expect(!SavedFilter(name: "Bugs", query: "label:bug status:failure").isScoped)
        #expect(!SavedFilter(name: "Not mine", query: "-author:@me").isScoped)
        #expect(!SavedFilter(name: "Empty", query: "repo: is:merged").isScoped)
        #expect(SavedFilter(name: "Merged", query: "author:@me is:merged").isScoped)
        #expect(SavedFilter(name: "Org", query: "org:acme is:merged").isScoped)
        #expect(SavedFilter(name: "Repo", query: "label:bug REPO:acme/api").isScoped)
        #expect(SavedFilter(name: "Team", query: "team-review-requested:acme/web").isScoped)
    }

    @Test func examplesAreReadyToSave() {
        let examples = SavedFilter.examples
        #expect(examples.allSatisfy { $0.isComplete && $0.isScoped })
        #expect(examples.allSatisfy { $0.preset == nil })
        #expect(Set(examples.map(\.query)).count == examples.count)
    }

    @Test func tabsSavedBeforeSortingKeepTheirOrder() throws {
        let saved = #"{"id":"6F9E2A48-4C1B-4E4B-9A55-3C1A5D7E9B10","name":"API","query":"repo:acme/api"}"#
        let filter = try JSONDecoder().decode(SavedFilter.self, from: Data(saved.utf8))
        #expect(filter.sort == nil)
    }
}
