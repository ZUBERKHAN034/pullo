import Foundation

protocol RunSource: Sendable {
    func pushedRepos(for account: Account) async throws -> [String]
    func runs(in repo: String, for account: Account) async throws -> [WorkflowRun]
    func jobs(of run: WorkflowRun, for account: Account) async throws -> [WorkflowJob]
    func rerunFailedJobs(of run: WorkflowRun, for account: Account) async throws
    func cancel(_ run: WorkflowRun, for account: Account) async throws
}

struct NoRuns: RunSource {
    func pushedRepos(for account: Account) async throws -> [String] { [] }
    func runs(in repo: String, for account: Account) async throws -> [WorkflowRun] { [] }
    func jobs(of run: WorkflowRun, for account: Account) async throws -> [WorkflowJob] { [] }
    func rerunFailedJobs(of run: WorkflowRun, for account: Account) async throws {}
    func cancel(_ run: WorkflowRun, for account: Account) async throws {}
}
