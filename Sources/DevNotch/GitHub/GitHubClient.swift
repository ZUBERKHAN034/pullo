import Foundation
import OSLog

struct GitHubClient {
    let token: String
    var session: URLSession = .shared

    private static let query = """
    query($mine: String!, $review: String!) {
      mine: search(query: $mine, type: ISSUE, first: 40) { nodes { ...pr } }
      review: search(query: $review, type: ISSUE, first: 40) { nodes { ...pr } }
    }
    fragment pr on PullRequest {
      id number title url isDraft createdAt updatedAt reviewDecision mergeable headRefName
      additions deletions changedFiles
      repository { nameWithOwner }
      author { login avatarUrl }
      headRefOid
      commitCount: commits { totalCount }
      comments(last: 20) { nodes { id author { __typename login avatarUrl } } }
      reviews(last: 20) { nodes { id author { __typename login avatarUrl } } }
      latestReviews(first: 20) { nodes { state author { login avatarUrl } } }
      reviewRequests(first: 20) { nodes { requestedReviewer { __typename ... on User { login } ... on Team { name } } } }
      commits(last: 1) { nodes { commit { statusCheckRollup {
        state
        contexts(first: 30) { totalCount nodes {
          ... on CheckRun { name conclusion detailsUrl }
          ... on StatusContext { context state targetUrl }
        } }
      } } } }
    }
    """

    func fetchSnapshot(account: String) async throws -> Snapshot {
        var request = request(for: URL(static: "https://api.github.com/graphql"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": Self.query,
            "variables": [
                "mine": "is:pr is:open author:@me archived:false sort:updated-desc",
                "review": "is:pr is:open review-requested:@me archived:false sort:updated-desc",
            ],
        ])

        let data = try await send(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GQLResponse.self, from: data)
        if let errors = decoded.errors, !errors.isEmpty {
            Logger.github.error("GitHub reported errors: \(errors.map(\.message).joined(separator: " | "), privacy: .public)")
        }
        guard let payload = decoded.data else {
            throw GitHubError.api(decoded.errors?.map(\.message).joined(separator: "\n") ?? "Empty response from GitHub.")
        }
        return Snapshot(
            mine: payload.mine.nodes.compactMap { $0.value?.pullRequest(account: account) },
            reviewRequests: payload.review.nodes.compactMap { $0.value?.pullRequest(account: account) }
        )
    }

    private static let outcomesQuery = """
    query($ids: [ID!]!) {
      nodes(ids: $ids) { ... on PullRequest {
        id state
        mergedBy { login avatarUrl }
        timelineItems(last: 1, itemTypes: [CLOSED_EVENT]) { nodes { ... on ClosedEvent { actor { login avatarUrl } } } }
      } }
    }
    """

    func fetchOutcomes(ids: [String]) async throws -> [PROutcome] {
        var request = request(for: URL(static: "https://api.github.com/graphql"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": Self.outcomesQuery, "variables": ["ids": ids]])
        let decoded = try await JSONDecoder().decode(OutcomeResponse.self, from: send(request))
        return decoded.data?.nodes.compactMap { $0.value?.outcome } ?? []
    }

    func fetchUser() async throws -> GitHubUser {
        struct Payload: Decodable {
            let login: String
            let avatar_url: URL?
        }
        let data = try await send(request(for: URL(static: "https://api.github.com/user")))
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return GitHubUser(login: payload.login, avatarURL: payload.avatar_url)
    }

    private func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("DevNotch", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(status) {
            Logger.github.error("\(request.url?.path() ?? "", privacy: .public) returned \(status)")
        }
        if status == 401 { throw GitHubError.unauthorized }
        guard (200..<300).contains(status) else {
            struct Failure: Decodable { let message: String }
            if let failure = try? JSONDecoder().decode(Failure.self, from: data) {
                throw GitHubError.api(failure.message)
            }
            throw GitHubError.http(status)
        }
        return data
    }
}
