@testable import DevNotch
import Foundation

extension WorkflowRun {
    static func make(
        id: Int = 1,
        account: String = "me",
        repo: String = "acme/api",
        workflow: String = "CI",
        branch: String = "main",
        state: State = .passed,
        actor: String = "me",
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) -> WorkflowRun {
        WorkflowRun(
            id: id,
            account: account,
            repo: repo,
            workflow: workflow,
            title: "Run \(id)",
            branch: branch,
            event: "push",
            state: state,
            url: URL(static: "https://github.com/acme/api/actions/runs/1"),
            actor: actor,
            triggeringActor: actor,
            createdAt: createdAt,
            startedAt: createdAt,
            updatedAt: createdAt,
            pullRequest: nil
        )
    }
}

actor StubRunSource: RunSource {
    private let pushed: [String]
    private var byRepo: [String: [WorkflowRun]]
    private(set) var runRequests: [String] = []
    private(set) var jobRequests: [Int] = []
    private var failsDiscovery: Bool

    init(pushed: [String] = [], runs: [String: [WorkflowRun]] = [:], failsDiscovery: Bool = false) {
        self.pushed = pushed
        byRepo = runs
        self.failsDiscovery = failsDiscovery
    }

    func set(_ runs: [WorkflowRun], in repo: String) { byRepo[repo] = runs }

    func pushedRepos(for account: Account) async throws -> [String] {
        if failsDiscovery { throw GitHubError.api("Not Found") }
        return pushed
    }

    func runs(in repo: String, for account: Account) async throws -> [WorkflowRun] {
        runRequests.append(repo)
        return byRepo[repo] ?? []
    }

    func jobs(of run: WorkflowRun, for account: Account) async throws -> JobProgress {
        jobRequests.append(run.id)
        return JobProgress(done: 2, total: 5, failed: 0, current: "test")
    }
}
