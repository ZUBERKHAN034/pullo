import Foundation
@testable import Pullo

extension WorkflowRun {
    static func make(
        id: Int = 1,
        account: String = "me",
        repo: String = "acme/api",
        workflow: String = "CI",
        branch: String = "main",
        state: State = .passed,
        actor: String = "me",
        createdAt: Date = Date(timeIntervalSince1970: 0),
        pullRequest: Int? = nil,
        event: String = "push"
    ) -> WorkflowRun {
        WorkflowRun(
            id: id,
            account: account,
            repo: repo,
            workflow: workflow,
            title: "Run \(id)",
            branch: branch,
            event: event,
            state: state,
            url: URL(static: "https://github.com/acme/api/actions/runs/1"),
            actor: actor,
            triggeringActor: actor,
            createdAt: createdAt,
            startedAt: createdAt,
            updatedAt: createdAt,
            pullRequest: pullRequest
        )
    }
}

actor StubRunSource: RunSource {
    private let pushed: [String]
    private var byRepo: [String: [WorkflowRun]]
    private(set) var runRequests: [String] = []
    private(set) var jobRequests: [Int] = []
    private var failsDiscovery: Bool
    private var jobLists: [Int: [WorkflowJob]] = [:]
    private var failsCommands = false
    private var runsFailure: GitHubError?
    private var repoFailures: [String: GitHubError] = [:]
    private(set) var commands: [String] = []

    init(pushed: [String] = [], runs: [String: [WorkflowRun]] = [:], failsDiscovery: Bool = false) {
        self.pushed = pushed
        byRepo = runs
        self.failsDiscovery = failsDiscovery
    }

    func set(_ runs: [WorkflowRun], in repo: String) { byRepo[repo] = runs }

    func failRuns(with error: GitHubError?) { runsFailure = error }

    func failRuns(in repo: String, with error: GitHubError?) { repoFailures[repo] = error }

    func pushedRepos(for account: Account) async throws -> [String] {
        if failsDiscovery { throw GitHubError.api("Not Found") }
        return pushed
    }

    func runs(in repo: String, for account: Account) async throws -> [WorkflowRun] {
        runRequests.append(repo)
        if let runsFailure { throw runsFailure }
        if let failure = repoFailures[repo] { throw failure }
        return byRepo[repo] ?? []
    }

    func jobs(of run: WorkflowRun, for account: Account) async throws -> [WorkflowJob] {
        jobRequests.append(run.id)
        if let list = jobLists[run.id] { return list }
        return [
            .make(id: 1, name: "lint", state: .passed),
            .make(id: 2, name: "build", state: .passed),
            .make(id: 3, name: "test", state: .running),
            .make(id: 4, name: "deploy", state: .queued),
            .make(id: 5, name: "notify", state: .queued),
        ]
    }

    func setJobs(_ list: [WorkflowJob], of run: Int) { jobLists[run] = list }

    func failCommands() { failsCommands = true }

    func rerunFailedJobs(of run: WorkflowRun, for account: Account) async throws {
        if failsCommands { throw GitHubError.http(403) }
        commands.append("rerun \(run.id)")
    }

    func cancel(_ run: WorkflowRun, for account: Account) async throws {
        if failsCommands { throw GitHubError.http(403) }
        commands.append("cancel \(run.id)")
    }
}

extension WorkflowJob {
    static func make(id: Int, name: String, state: WorkflowRun.State, failedStep: String? = nil) -> WorkflowJob {
        WorkflowJob(
            id: id,
            name: name,
            state: state,
            url: URL(static: "https://github.com/acme/api/actions/runs/1/job/1"),
            startedAt: Date(timeIntervalSince1970: 0),
            completedAt: state.isActive ? nil : Date(timeIntervalSince1970: 60),
            steps: failedStep.map { [WorkflowStep(number: 1, name: $0, state: .failed, startedAt: nil, completedAt: nil)] } ?? []
        )
    }
}
