import Foundation
import os
@testable import Pullo
import Testing

struct GitHubClientTests {
    private func client(status: Int = 200, body: String) -> (GitHubClient, String) {
        let token = UUID().uuidString
        return (
            GitHubClient(token: token, session: StubURLProtocol.session(token: token, status: status, body: body), retryDelays: [
                .zero,
                .zero,
            ]),
            token
        )
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
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Pullo")
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
        let (client, _) = client(status: 422, body: #"{ "message": "Validation Failed" }"#)
        await #expect(throws: GitHubError.api("Validation Failed")) { try await client.fetchUser() }
    }

    @Test func aBlockedRepoIsForbidden() async {
        let message = "Resource protected by organization SAML enforcement. You must grant your Personal Access token access to this organization."
        let (client, _) = client(status: 403, body: #"{ "message": "\#(message)" }"#)
        await #expect(throws: GitHubError.forbidden(message)) { try await client.fetchUser() }
    }

    @Test func errorsWithoutABodyKeepTheStatus() async {
        let (client, _) = client(status: 418, body: "")
        await #expect(throws: GitHubError.http(418)) { try await client.fetchUser() }
    }

    private func client(_ responses: [StubURLProtocol.Response]) -> (GitHubClient, String) {
        let token = UUID().uuidString
        let session = StubURLProtocol.session(token: token, responses: responses)
        return (GitHubClient(token: token, session: session, retryDelays: [.zero, .zero]), token)
    }

    private let user = StubURLProtocol.Response(status: 200, body: #"{ "login": "me", "avatar_url": null }"#)

    @Test func aBadGatewayIsTriedAgain() async throws {
        let (client, token) = client([.init(status: 502, body: ""), user])
        #expect(try await client.fetchUser().login == "me")
        #expect(StubURLProtocol.requestCount(token: token) == 2)
    }

    @Test func givesUpAfterTwoMoreTries() async {
        let (client, token) = client([.init(status: 503, body: "")])
        await #expect(throws: GitHubError.server(503)) { try await client.fetchUser() }
        #expect(StubURLProtocol.requestCount(token: token) == 3)
    }

    @Test func commandsAreNeverSentTwice() async {
        let (client, token) = client([.init(status: 502, body: ""), .init(status: 201, body: "")])
        await #expect(throws: GitHubError.server(502)) { try await client.rerunFailedJobs(in: "acme/api", run: 9) }
        #expect(StubURLProtocol.requestCount(token: token) == 1)
    }

    @Test func noConnectionMeansOfflineAndIsNotTriedAgain() async {
        let (client, token) = client([.offline()])
        await #expect(throws: GitHubError.offline) { try await client.fetchUser() }
        #expect(StubURLProtocol.requestCount(token: token) == 1)
    }

    @Test func aSlowAnswerIsTriedAgainButDoesNotDowngradeTheQuery() async throws {
        let account = UUID().uuidString
        let page = StubURLProtocol.Response(status: 200, body: #"{ "data": { "mine": { "nodes": [] }, "review": { "nodes": [] } } }"#)
        let (client, token) = client([.init(status: 0, body: "", failure: .timedOut), page])
        _ = try await client.fetchSnapshot(account: account)
        #expect(StubURLProtocol.requestCount(token: token) == 2)
        #expect(StubURLProtocol.bodies(token: token).allSatisfy { $0.contains("first: 40") })
        #expect(!client.sizes.usesLight(account))
    }

    @Test func theLightQueryIsDroppedAfterAWhile() async throws {
        let account = UUID().uuidString
        let clock = OSAllocatedUnfairLock(initialState: Date(timeIntervalSince1970: 1_000_000))
        let sizes = QuerySizes { clock.withLock { $0 } }
        let page = StubURLProtocol.Response(status: 200, body: #"{ "data": { "mine": { "nodes": [] }, "review": { "nodes": [] } } }"#)
        var (client, token) = client([.init(status: 502, body: ""), page])
        client.sizes = sizes
        _ = try await client.fetchSnapshot(account: account)
        #expect(sizes.usesLight(account))
        clock.withLock { $0 += QuerySizes.downgradeTime - 1 }
        #expect(sizes.usesLight(account))
        clock.withLock { $0 += 2 }
        #expect(!sizes.usesLight(account))
        _ = try await client.fetchSnapshot(account: account)
        #expect(StubURLProtocol.bodies(token: token).last?.contains("first: 40") == true)
    }

    @Test func aSpentRateLimitSaysWhenItResets() async {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let (client, _) = client([.init(
            status: 403,
            body: #"{ "message": "API rate limit exceeded for user." }"#,
            headers: ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1800000000"]
        )])
        await #expect(throws: GitHubError.rateLimited(until: reset)) { try await client.fetchUser() }
    }

    @Test func aSecondaryRateLimitIsNotAPermissionError() async {
        let (client, _) = client([.init(status: 403, body: #"{ "message": "You have exceeded a secondary rate limit." }"#)])
        await #expect(throws: GitHubError.rateLimited(until: nil)) { try await client.fetchUser() }
    }

    @Test func aQueryTooBigForGitHubSwitchesToALighterOne() async throws {
        let account = UUID().uuidString
        let page = StubURLProtocol.Response(status: 200, body: #"{ "data": { "mine": { "nodes": [] }, "review": { "nodes": [] } } }"#)
        let (client, token) = client([.init(status: 502, body: ""), page])
        _ = try await client.fetchSnapshot(account: account)
        _ = try await client.fetchSnapshot(account: account)
        let bodies = StubURLProtocol.bodies(token: token)
        #expect(bodies.count == 3)
        #expect(bodies[0].contains("first: 40"))
        #expect(bodies[1].contains("first: 15"))
        #expect(bodies[2].contains("first: 15"))
        #expect(client.sizes.usesLight(account))
    }

    @Test func aGraphQLTimeoutCountsAsOverloaded() async throws {
        let account = UUID().uuidString
        let timeout = StubURLProtocol.Response(
            status: 200,
            body: #"{ "data": null, "errors": [ { "message": "Something went wrong while executing your query. This may be the result of a timeout, or it could be a GitHub bug." } ] }"#
        )
        let page = StubURLProtocol.Response(status: 200, body: #"{ "data": { "mine": { "nodes": [] }, "review": { "nodes": [] } } }"#)
        let (client, token) = client([timeout, page])
        _ = try await client.fetchSnapshot(account: account)
        #expect(StubURLProtocol.requestCount(token: token) == 2)
        #expect(client.sizes.usesLight(account))
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
