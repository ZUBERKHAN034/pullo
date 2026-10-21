@testable import DevNotch
import Foundation
import Testing

struct GitHubClientTests {
    private func client(status: Int = 200, body: String) -> (GitHubClient, String) {
        let token = UUID().uuidString
        return (GitHubClient(token: token, session: StubURLProtocol.session(token: token, status: status, body: body)), token)
    }

    private let prNode = """
    { "id": "PR_1", "number": 7, "title": "feat: x", "url": "https://github.com/acme/api/pull/7",
      "isDraft": false, "createdAt": "2026-10-01T12:00:00Z", "updatedAt": "2026-10-02T12:00:00Z",
      "reviewDecision": null, "mergeable": "MERGEABLE", "headRefName": "feat/x",
      "repository": { "nameWithOwner": "acme/api" }, "author": { "login": "me" },
      "headRefOid": "abc", "commitCount": { "totalCount": 1 },
      "comments": { "nodes": [] }, "reviews": { "nodes": [] }, "latestReviews": { "nodes": [] },
      "reviewRequests": { "nodes": [] }, "commits": { "nodes": [] } }
    """

    @Test func sendsTheTokenAndAUserAgent() async throws {
        let (client, token) = client(body: #"{ "login": "me", "avatar_url": null }"#)
        _ = try await client.fetchUser()
        let request = try #require(StubURLProtocol.lastRequest(token: token))
        #expect(request.value(forHTTPHeaderField: "Authorization") == "bearer \(token)")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "DevNotch")
    }

    @Test func readsTheUserProfile() async throws {
        let (client, _) = client(body: #"{ "login": "ana", "avatar_url": "https://avatars.githubusercontent.com/u/1" }"#)
        let user = try await client.fetchUser()
        #expect(user.login == "ana")
        #expect(user.avatarURL?.host() == "avatars.githubusercontent.com")
    }

    @Test func rejectedTokensAreUnauthorized() async {
        let (client, _) = client(status: 401, body: #"{ "message": "Bad credentials" }"#)
        await #expect(throws: GitHubError.unauthorized) { try await client.fetchUser() }
    }

    @Test func restErrorsCarryGitHubsReason() async {
        let (client, _) = client(status: 403, body: #"{ "message": "Resource not accessible by integration" }"#)
        await #expect(throws: GitHubError.api("Resource not accessible by integration")) { try await client.fetchUser() }
    }

    @Test func errorsWithoutABodyKeepTheStatus() async {
        let (client, _) = client(status: 502, body: "")
        await #expect(throws: GitHubError.http(502)) { try await client.fetchUser() }
    }

    @Test func partialDataIsKeptWhenAnOrgBlocksTheToken() async throws {
        let body = """
        { "data": { "mine": { "nodes": [\(prNode), {}] }, "review": { "nodes": [] } },
          "errors": [ { "message": "Resource protected by organization SAML enforcement." } ] }
        """
        let (client, _) = client(body: body)
        let snapshot = try await client.fetchSnapshot(account: "me")
        #expect(snapshot.mine.map(\.id) == ["PR_1"])
        #expect(snapshot.reviewRequests.isEmpty)
    }

    @Test func eachFilterIsItsOwnSearch() async throws {
        let api = SavedFilter(name: "API", query: "repo:acme/api")
        let broken = SavedFilter(name: "Broken", query: "repo:nobody/nothing")
        let unfinished = SavedFilter(name: "", query: "repo:acme/web")
        let body = """
        { "data": { "mine": { "nodes": [] }, "review": { "nodes": [] }, "f0": { "nodes": [\(prNode)] }, "f1": null },
          "errors": [ { "message": "The listed repositories cannot be searched.", "path": ["f1"] } ] }
        """
        let (client, token) = client(body: body)
        let snapshot = try await client.fetchSnapshot(account: "me", filters: SavedFilter.defaults + [api, broken, unfinished])
        #expect(snapshot.filtered[api.id]?.map(\.id) == ["PR_1"])
        #expect(snapshot.filtered[broken.id]?.isEmpty == true)
        #expect(snapshot.filterErrors[broken.id] == "The listed repositories cannot be searched.")
        #expect(snapshot.filtered[unfinished.id] == nil)

        let request = try #require(StubURLProtocol.lastRequest(token: token))
        let sent = try #require(try JSONSerialization.jsonObject(with: sentBody(of: request)) as? [String: Any])
        let variables = try #require(sent["variables"] as? [String: String])
        #expect(variables["f0"] == api.searchQuery)
        #expect(variables["f1"] == broken.searchQuery)
        #expect(variables["f2"] == nil)
        #expect((sent["query"] as? String)?.contains("f1: search(query: $f1") == true)
    }

    private func sentBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }

    @Test func graphQLErrorsWithoutDataAreReported() async {
        let body = #"{ "data": null, "errors": [ { "message": "first" }, { "message": "second" } ] }"#
        let (client, _) = client(body: body)
        await #expect(throws: GitHubError.api("first\nsecond")) { try await client.fetchSnapshot(account: "me") }
    }
}
