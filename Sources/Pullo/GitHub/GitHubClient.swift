import Foundation
import OSLog

struct GitHubClient {
    let token: String
    var session: URLSession = .github
    var sizes = QuerySizes()
    var retryDelays: [Duration] = [.seconds(1), .seconds(3)]

    struct QuerySize: Equatable {
        let prs: Int
        let checks: Int
        let activity: Int

        static let full = QuerySize(prs: 40, checks: 30, activity: 20)
        static let light = QuerySize(prs: 15, checks: 15, activity: 10)
    }

    static func query(filterCount: Int, size: QuerySize = .full) -> String {
        let aliases = (0..<filterCount).map { "f\($0)" }
        let variables = (["mine", "review"] + aliases).map { "$\($0): String!" }.joined(separator: ", ")
        let searches = (["mine", "review"] + aliases)
            .map { "  \($0): search(query: $\($0), type: ISSUE, first: \(size.prs)) { nodes { ...pr } }" }
        return "query(\(variables)) {\n\(searches.joined(separator: "\n"))\n}\n" + fragment(size)
    }

    private static func fragment(_ size: QuerySize) -> String {
        """
        fragment pr on PullRequest {
          id number title url isDraft createdAt updatedAt reviewDecision mergeable headRefName
          additions deletions changedFiles
          repository { nameWithOwner }
          author { login avatarUrl }
          headRefOid
          commitCount: commits { totalCount }
          comments(last: \(size.activity)) { nodes { id author { __typename login avatarUrl } } }
          reviews(last: \(size.activity)) { nodes { id author { __typename login avatarUrl } } }
          latestReviews(first: \(size.activity)) { nodes { state author { login avatarUrl } } }
          reviewRequests(first: \(size.activity)) { nodes { requestedReviewer { __typename ... on User { login } ... on Team { name } } } }
          commits(last: 1) { nodes { commit { statusCheckRollup {
            state
            contexts(first: \(size.checks)) { totalCount nodes {
              ... on CheckRun { name conclusion detailsUrl }
              ... on StatusContext { context state targetUrl }
            } }
          } } } }
        }
        """
    }

    func fetchSnapshot(account: String, filters: [SavedFilter] = []) async throws -> Snapshot {
        if sizes.usesLight(account) {
            return try await fetchSnapshot(account: account, filters: filters, size: .light, retriesOverload: true)
        }
        do {
            return try await fetchSnapshot(account: account, filters: filters, size: .full, retriesOverload: false)
        } catch let error as GitHubError where error.isOverloaded {
            Logger.github
                .notice(
                    "The full query for @\(account, privacy: .private(mask: .hash)) failed (\(String(describing: error), privacy: .public)); using the light one for a while"
                )
            sizes.downgrade(account)
            return try await fetchSnapshot(account: account, filters: filters, size: .light, retriesOverload: true)
        }
    }

    private func fetchSnapshot(
        account: String,
        filters: [SavedFilter],
        size: QuerySize,
        retriesOverload: Bool
    ) async throws -> Snapshot {
        let filters = filters.filter { $0.isComplete && !$0.usesBuiltInSearch }
        let aliases = Dictionary(uniqueKeysWithValues: filters.enumerated().map { ("f\($0.offset)", $0.element) })
        var request = request(for: URL(static: "https://api.github.com/graphql"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": Self.query(filterCount: filters.count, size: size),
            "variables": [
                "mine": "is:pr is:open author:@me archived:false sort:updated-desc",
                "review": "is:pr is:open review-requested:@me archived:false sort:updated-desc",
            ].merging(aliases.mapValues(\.searchQuery)) { $1 },
        ])

        let data = try await perform(request, retriesOverload: retriesOverload).data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GQLResponse.self, from: data)
        if let errors = decoded.errors, !errors.isEmpty {
            Logger.github.error("GitHub reported errors: \(errors.map(\.message).joined(separator: " | "), privacy: .private(mask: .hash))")
        }
        guard let payload = decoded.data else {
            if let failure = decoded.errors?.lazy.compactMap(\.failure).first { throw failure }
            throw GitHubError.api(decoded.errors?.map(\.message).joined(separator: "\n") ?? "Empty response from GitHub.")
        }
        var filtered: [SavedFilter.ID: [PullRequest]] = [:]
        var filterErrors: [SavedFilter.ID: String] = [:]
        for (alias, filter) in aliases {
            filtered[filter.id] = payload.filtered[alias]?.nodes.compactMap { $0.value?.pullRequest(account: account) } ?? []
            if let error = decoded.errors?.first(where: { $0.alias == alias }) { filterErrors[filter.id] = error.message }
        }
        return Snapshot(
            mine: payload.mine.nodes.compactMap { $0.value?.pullRequest(account: account) },
            reviewRequests: payload.review.nodes.compactMap { $0.value?.pullRequest(account: account) },
            filtered: filtered,
            filterErrors: filterErrors
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

    func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("Pullo", forHTTPHeaderField: "User-Agent")
        return request
    }

    func send(_ request: URLRequest) async throws -> Data {
        try await perform(request).data
    }

    func conditionalGet(_ url: URL, etag: String?) async throws -> Fetched<Data> {
        var request = request(for: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await perform(request, allowing: etag == nil ? [] : [304])
        if response.statusCode == 304 { return .notModified }
        return .fresh(data, etag: response.value(forHTTPHeaderField: "ETag"))
    }

    private func perform(
        _ request: URLRequest,
        allowing allowed: Set<Int> = [],
        retriesOverload: Bool = true
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        let delays = Self.canRetry(request) ? retryDelays : []
        var attempt = 0
        while true {
            do {
                return try await performOnce(request, allowing: allowed)
            } catch let error as GitHubError
                where error.isTransient && (retriesOverload || !error.isOverloaded) && attempt < delays.count {
                Logger.github
                    .notice(
                        "\(request.url?.path() ?? "", privacy: .private(mask: .hash)) failed (\(String(describing: error), privacy: .public)); trying again"
                    )
                try await Task.sleep(for: delays[attempt])
                attempt += 1
            }
        }
    }

    private static func canRetry(_ request: URLRequest) -> Bool {
        let method = request.httpMethod ?? "GET"
        return method == "GET" || request.url?.path() == "/graphql"
    }

    private func performOnce(_ request: URLRequest, allowing allowed: Set<Int>) async throws -> (data: Data, response: HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            Logger.github.error(
                "\(request.url?.path() ?? "", privacy: .private(mask: .hash)) failed: URLError \(error.code.rawValue, privacy: .public)"
            )
            throw GitHubError(error) ?? error
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        if allowed.contains(status), let http { return (data, http) }
        if !(200..<300).contains(status) {
            Logger.github.error("\(request.url?.path() ?? "", privacy: .private(mask: .hash)) returned \(status, privacy: .public)")
        }
        if status == 401 { throw GitHubError.unauthorized }
        if status == 403 || status == 429, let http, let limit = Self.rateLimit(http, data) { throw limit }
        if (500..<600).contains(status) { throw GitHubError.server(status) }
        guard (200..<300).contains(status), let http else {
            if let failure = try? JSONDecoder().decode(Failure.self, from: data) {
                throw status == 403 ? GitHubError.forbidden(failure.message) : GitHubError.api(failure.message)
            }
            throw GitHubError.http(status)
        }
        return (data, http)
    }

    private struct Failure: Decodable { let message: String }

    static func rateLimit(_ response: HTTPURLResponse, _ data: Data, now: Date = .now) -> GitHubError? {
        if let seconds = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init) {
            return .rateLimited(until: now.addingTimeInterval(seconds))
        }
        if response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
            let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(TimeInterval.init)
            return .rateLimited(until: reset.map(Date.init(timeIntervalSince1970:)))
        }
        let message = (try? JSONDecoder().decode(Failure.self, from: data))?.message ?? ""
        return message.localizedCaseInsensitiveContains("rate limit") ? .rateLimited(until: nil) : nil
    }
}
