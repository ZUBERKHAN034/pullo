@testable import DevNotch
import Foundation
import Testing

struct PRNodeTests {
    private func decode(_ json: String) throws -> PRNode {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PRNode.self, from: Data(json.utf8))
    }

    private let json = """
    {
      "id": "PR_1", "number": 383, "title": "feat: canal web", "url": "https://github.com/a/b/pull/383",
      "isDraft": false, "createdAt": "2026-10-01T12:00:00Z", "updatedAt": "2026-10-02T12:00:00Z",
      "reviewDecision": "CHANGES_REQUESTED", "mergeable": "CONFLICTING", "headRefName": "feat/canal-web",
      "repository": { "nameWithOwner": "acme/acme-api" },
      "author": { "login": "octavio" },
      "headRefOid": "abc", "commitCount": { "totalCount": 2 },
      "comments": { "nodes": [
        { "id": "c1", "author": { "__typename": "Bot", "login": "linear" } },
        { "id": "c2", "author": { "__typename": "User", "login": "Me" } },
        { "id": "c3", "author": { "__typename": "User", "login": "octavio" } }
      ] },
      "reviews": { "nodes": [
        { "id": "r1", "author": { "__typename": "Bot", "login": "gemini-code-assist" } },
        { "id": "r2", "author": { "__typename": "User", "login": "icaro" } }
      ] },
      "latestReviews": { "nodes": [ { "state": "CHANGES_REQUESTED", "author": { "login": "icaro" } } ] },
      "reviewRequests": { "nodes": [
        { "requestedReviewer": { "__typename": "Team", "name": "engineering" } },
        { "requestedReviewer": null }
      ] },
      "commits": { "nodes": [ { "commit": { "statusCheckRollup": {
        "state": "FAILURE",
        "contexts": { "nodes": [
          { "name": "Typecheck", "conclusion": "FAILURE", "detailsUrl": "https://github.com/a/b/runs/1" },
          { "name": "Lint", "conclusion": "SUCCESS", "detailsUrl": "https://github.com/a/b/runs/2" },
          { "context": "ci/legacy", "state": "ERROR", "targetUrl": "https://ci.example.com/3" }
        ] }
      } } } ] }
    }
    """

    @Test func mapsTheGitHubPayload() throws {
        let pr = try decode(json).pullRequest(account: "me")
        #expect(pr.repoName == "acme-api")
        #expect(pr.ci == .failure)
        #expect(pr.review == .changesRequested)
        #expect(pr.hasConflict)
        #expect(pr.changeRequesters == ["icaro"])
        #expect(pr.commitCount == 2)
    }

    @Test func ignoresBotsAndYourOwnActivity() throws {
        let pr = try decode(json).pullRequest(account: "me")
        #expect(pr.othersCommentIDs == ["c3"])
        #expect(pr.othersReviews == [Activity(id: "r2", author: "icaro")])
    }

    @Test func teamRequestUnlessYouWereAskedDirectly() throws {
        #expect(try decode(json).pullRequest(account: "me").reviewRequest == .team(["engineering"]))
        let direct = json.replacingOccurrences(
            of: #"{ "requestedReviewer": null }"#,
            with: #"{ "requestedReviewer": { "__typename": "User", "login": "me" } }"#
        )
        #expect(try decode(direct).pullRequest(account: "me").reviewRequest == .direct)
    }

    @Test func listsOnlyTheFailedChecks() throws {
        let checks = try decode(json).pullRequest(account: "me").failedChecks
        #expect(checks.map(\.name) == ["Typecheck", "ci/legacy"])
        #expect(checks.first?.url?.absoluteString == "https://github.com/a/b/runs/1")
    }
}
