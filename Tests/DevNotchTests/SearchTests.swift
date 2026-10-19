import Testing
@testable import DevNotch

struct SearchTests {
    let pr = PullRequest.make(number: 383, title: "feat: Canal Web", branch: "feat/canal-web", author: "octavio")

    @Test func matchesAnyField() {
        #expect(pr.matches("canal"))
        #expect(pr.matches("acme-api"))
        #expect(pr.matches("octavio"))
        #expect(pr.matches("feat/canal"))
    }

    @Test func numberWithOrWithoutHash() {
        #expect(pr.matches("#383"))
        #expect(pr.matches("383"))
        #expect(!pr.matches("#384"))
    }

    @Test func hashNumberIsExact() {
        #expect(!pr.matches("#38"))
        #expect(!pr.matches("#3"))
        #expect(!pr.matches("#"))
    }

    @Test func bareNumberStillSearchesText() {
        let release = PullRequest.make(number: 7, title: "Release 2026.10")
        #expect(release.matches("2026"))
        #expect(release.matches("7"))
    }

    @Test func everyWordHasToMatch() {
        #expect(pr.matches("canal octavio"))
        #expect(!pr.matches("canal jordan"))
    }

    @Test func emptyQueryMatchesNothing() {
        #expect(!pr.matches(""))
        #expect(!pr.matches("   "))
    }
}
