import Foundation

protocol RunSource: Sendable {
    func pushedRepos(for account: Account) async throws -> [String]
    func runs(in repo: String, for account: Account) async throws -> [WorkflowRun]
    func jobs(of run: WorkflowRun, for account: Account) async throws -> JobProgress
}

struct NoRuns: RunSource {
    func pushedRepos(for account: Account) async throws -> [String] { [] }
    func runs(in repo: String, for account: Account) async throws -> [WorkflowRun] { [] }
    func jobs(of run: WorkflowRun, for account: Account) async throws -> JobProgress {
        JobProgress(done: 0, total: 0, failed: 0, current: nil)
    }
}
