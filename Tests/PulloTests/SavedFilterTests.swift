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

    @Test func accountsSavedBeforeTabsGetTheDefaultOnes() throws {
        let json = #"[{ "login": "me", "avatarURL": null }]"#
        let accounts = try JSONDecoder().decode([Account].self, from: Data(json.utf8))
        #expect(accounts.first?.filters.map(\.preset) == [.mine, .review])
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

    @Test func examplesAreReadyToSave() {
        let examples = SavedFilter.examples
        #expect(examples.allSatisfy { $0.isComplete })
        #expect(examples.allSatisfy { $0.preset == nil })
        #expect(Set(examples.map(\.query)).count == examples.count)
    }
}
