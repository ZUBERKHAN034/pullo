@testable import DevNotch
import Foundation
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

    @Test func accountsSavedBeforeFiltersStillLoad() throws {
        let json = #"[{ "login": "me", "avatarURL": null }]"#
        let accounts = try JSONDecoder().decode([Account].self, from: Data(json.utf8))
        #expect(accounts.first?.filters == [])
    }
}
