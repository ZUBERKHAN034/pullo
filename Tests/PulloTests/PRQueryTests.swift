@testable import Pullo
import Testing

struct PRQueryTests {
    @Test func readsTheDefaultTabs() {
        #expect(PRQuery(parsing: "author:@me").author == .me)
        #expect(PRQuery(parsing: "review-requested:@me").review == .requestedFromMe)
        #expect(PRQuery(parsing: "author:@me").text == "author:@me")
        #expect(PRQuery(parsing: "review-requested:@me").text == "review-requested:@me")
    }

    @Test func readsEveryField() {
        let query = PRQuery(parsing: "author:ana review:approved repo:acme/api label:\"good first issue\" status:failure draft:true")
        #expect(query.author == .user)
        #expect(query.user == "ana")
        #expect(query.review == .approved)
        #expect(query.repo == "acme/api")
        #expect(query.label == "good first issue")
        #expect(query.checks == .failing)
        #expect(query.state == .drafts)
        #expect(query.extra.isEmpty)
        #expect(query.text == "author:ana review:approved repo:acme/api label:\"good first issue\" status:failure draft:true")
    }

    @Test func keepsWhatTheFieldsCantShow() {
        let query = PRQuery(parsing: "label:bug label:api -author:@me team-review-requested:acme/web")
        #expect(query.label == "bug")
        #expect(query.extra == "label:api -author:@me team-review-requested:acme/web")
        #expect(query.text == "label:bug label:api -author:@me team-review-requested:acme/web")
    }

    @Test func buildsTheSearchFromTheFields() {
        var query = PRQuery()
        query.author = .me
        query.checks = .running
        query.state = .ready
        #expect(query.text == "author:@me status:pending draft:false")
        query.author = .user
        query.user = "@ana"
        #expect(query.text == "author:ana status:pending draft:false")
    }

    @Test func someoneElseNeedsALogin() {
        var query = PRQuery()
        query.author = .user
        #expect(!query.isComplete)
        #expect(query.text.isEmpty)
        query.user = "ana"
        #expect(query.isComplete)
    }

    @Test func openIsTheDefaultState() {
        #expect(PRQuery(parsing: "author:@me is:open").state == .open)
        #expect(PRQuery(parsing: "author:@me is:open").text == "author:@me")
        #expect(PRQuery(parsing: "is:merged").state == .merged)
        #expect(PRQuery(parsing: "is:draft").state == .drafts)
    }
}
