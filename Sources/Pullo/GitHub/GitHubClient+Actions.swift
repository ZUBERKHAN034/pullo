import Foundation

enum Fetched<Value> {
    case fresh(Value, etag: String?)
    case notModified
}

extension GitHubClient {
    func fetchPushedRepos(login: String) async throws -> [String] {
        struct Event: Decodable {
            struct Repo: Decodable { let name: String }
            let type: String
            let repo: Repo
        }
        let url = URL(static: "https://api.github.com/users").appending(path: login).appending(path: "events")
            .appending(queryItems: [URLQueryItem(name: "per_page", value: "100")])
        let data = try await send(request(for: url))
        let events = try Self.restDecoder.decode([Event].self, from: data)
        var seen = Set<String>()
        return events.filter { $0.type == "PushEvent" }.map(\.repo.name).filter { seen.insert($0).inserted }
    }

    func fetchRuns(in repo: String, account: String, etag: String?) async throws -> Fetched<[WorkflowRun]> {
        let url = URL(static: "https://api.github.com/repos").appending(path: repo).appending(path: "actions/runs")
            .appending(queryItems: [URLQueryItem(name: "per_page", value: "30")])
        guard case .fresh(let data, let etag) = try await conditionalGet(url, etag: etag) else { return .notModified }
        let payload = try Self.restDecoder.decode(RunsPayload.self, from: data)
        return .fresh(payload.workflowRuns.map { $0.run(account: account, repo: repo) }, etag: etag)
    }

    func fetchJobs(in repo: String, run: Int, etag: String?) async throws -> Fetched<[WorkflowJob]> {
        let url = runURL(repo, run).appending(path: "jobs")
            .appending(queryItems: [URLQueryItem(name: "per_page", value: "100")])
        guard case .fresh(let data, let etag) = try await conditionalGet(url, etag: etag) else { return .notModified }
        return try .fresh(Self.restDecoder.decode(JobsPayload.self, from: data).jobs.map(\.job), etag: etag)
    }

    func rerunFailedJobs(in repo: String, run: Int) async throws {
        try await post(runURL(repo, run).appending(path: "rerun-failed-jobs"))
    }

    func cancelRun(in repo: String, run: Int) async throws {
        try await post(runURL(repo, run).appending(path: "cancel"))
    }

    private func runURL(_ repo: String, _ run: Int) -> URL {
        URL(static: "https://api.github.com/repos").appending(path: repo).appending(path: "actions/runs/\(run)")
    }

    private func post(_ url: URL) async throws {
        var request = request(for: url)
        request.httpMethod = "POST"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        _ = try await send(request)
    }

    static let restDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private struct RunsPayload: Decodable {
    struct Run: Decodable {
        struct User: Decodable { let login: String }
        struct PullRequest: Decodable { let number: Int }

        let id: Int
        let name: String?
        let displayTitle: String?
        let headBranch: String?
        let event: String
        let status: String?
        let conclusion: String?
        let htmlUrl: URL
        let actor: User?
        let triggeringActor: User?
        let createdAt: Date
        let runStartedAt: Date?
        let updatedAt: Date
        let pullRequests: [PullRequest]?

        func run(account: String, repo: String) -> WorkflowRun {
            WorkflowRun(
                id: id,
                account: account,
                repo: repo,
                workflow: name ?? "Workflow",
                title: displayTitle ?? "",
                branch: headBranch,
                event: event,
                state: WorkflowRun.state(status: status ?? "queued", conclusion: conclusion),
                url: htmlUrl,
                actor: actor?.login,
                triggeringActor: triggeringActor?.login,
                createdAt: createdAt,
                startedAt: runStartedAt ?? createdAt,
                updatedAt: updatedAt,
                pullRequest: pullRequests?.first?.number
            )
        }
    }

    let workflowRuns: [Run]
}

private struct JobsPayload: Decodable {
    struct Job: Decodable {
        struct Step: Decodable {
            let number: Int?
            let name: String
            let status: String
            let conclusion: String?
            let startedAt: Date?
            let completedAt: Date?
        }

        let id: Int
        let name: String
        let status: String
        let conclusion: String?
        let htmlUrl: URL?
        let startedAt: Date?
        let completedAt: Date?
        let steps: [Step]?

        var job: WorkflowJob {
            let state = WorkflowRun.state(status: status, conclusion: conclusion)
            return WorkflowJob(
                id: id,
                name: name,
                state: state,
                url: htmlUrl,
                startedAt: startedAt,
                completedAt: state.isActive ? nil : completedAt,
                steps: (steps ?? []).enumerated().map { index, step in
                    let state = WorkflowRun.state(status: step.status, conclusion: step.conclusion)
                    return WorkflowStep(
                        number: step.number ?? index + 1,
                        name: step.name,
                        state: state,
                        startedAt: step.startedAt,
                        completedAt: state.isActive ? nil : step.completedAt
                    )
                }
            )
        }
    }

    let jobs: [Job]
}
