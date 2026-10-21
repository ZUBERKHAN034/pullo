import Foundation
@testable import Pullo
import Testing

struct WorkflowRunTests {
    private static let etag = #"W/"abc""#

    @Test(arguments: [
        ("in_progress", nil, WorkflowRun.State.running),
        ("queued", nil, .queued),
        ("requested", nil, .queued),
        ("waiting", nil, .waiting),
        ("completed", "success", .passed),
        ("completed", "failure", .failed),
        ("completed", "timed_out", .failed),
        ("completed", "cancelled", .cancelled),
        ("completed", "skipped", .skipped),
        ("completed", "action_required", .waiting),
    ] as [(String, String?, WorkflowRun.State)])
    func readsTheStateFromStatusAndConclusion(status: String, conclusion: String?, state: WorkflowRun.State) {
        #expect(WorkflowRun.state(status: status, conclusion: conclusion) == state)
    }

    @Test func formatsDurations() {
        #expect(RunRow.duration(42) == "42s")
        #expect(RunRow.duration(220) == "3m 40s")
        #expect(RunRow.duration(3900) == "1h 5m")
    }

    private func client(status: Int = 200, body: String) -> (GitHubClient, String) {
        let token = UUID().uuidString
        return (GitHubClient(token: token, session: StubURLProtocol.session(token: token, status: status, body: body)), token)
    }

    @Test func readsRunsFromTheRESTAPI() async throws {
        let (client, _) = client(body: """
        { "total_count": 1, "workflow_runs": [{
          "id": 9, "name": "Deploy", "display_title": "Release 1.4", "head_branch": "main", "event": "push",
          "status": "in_progress", "conclusion": null, "html_url": "https://github.com/acme/api/actions/runs/9",
          "actor": { "login": "me" }, "triggering_actor": { "login": "me" },
          "created_at": "2026-10-21T12:00:00Z", "run_started_at": "2026-10-21T12:00:05Z", "updated_at": "2026-10-21T12:01:00Z",
          "pull_requests": [{ "number": 41 }]
        }] }
        """)
        guard case .fresh(let runs, _) = try await client.fetchRuns(in: "acme/api", account: "me", etag: nil) else {
            Issue.record("Expected fresh runs")
            return
        }
        let run = try #require(runs.first)
        #expect(run.workflow == "Deploy")
        #expect(run.state == .running)
        #expect(run.pullRequest == 41)
        #expect(run.isDeploy)
        #expect(run.isStarted(by: "me"))
        #expect(run.startedAt.timeIntervalSince(run.createdAt) == 5)
    }

    @Test func sendsTheETagAndKeepsTheOldRunsWhenNothingChanged() async throws {
        let (client, token) = client(status: 304, body: "")
        let result = try await client.fetchRuns(in: "acme/api", account: "me", etag: Self.etag)
        guard case .notModified = result else {
            Issue.record("Expected not modified")
            return
        }
        #expect(StubURLProtocol.lastRequest(token: token)?.value(forHTTPHeaderField: "If-None-Match") == Self.etag)
    }

    @Test func countsJobsAndFindsTheOneRunning() async throws {
        let (client, _) = client(body: """
        { "total_count": 3, "jobs": [
          { "id": 1, "name": "lint", "status": "completed", "conclusion": "success" },
          { "id": 2, "name": "test", "status": "completed", "conclusion": "failure",
            "html_url": "https://github.com/acme/api/actions/runs/9/job/2",
            "started_at": "2026-10-21T10:00:00Z", "completed_at": "2026-10-21T10:02:00Z",
            "steps": [
              { "number": 1, "name": "Set up job", "status": "completed", "conclusion": "success",
                "started_at": "2026-10-21T10:00:00Z", "completed_at": "2026-10-21T10:00:05Z" },
              { "number": 2, "name": "Run tests", "status": "completed", "conclusion": "failure" },
              { "number": 3, "name": "Upload", "status": "completed", "conclusion": "skipped" }
            ] },
          { "id": 3, "name": "build", "status": "in_progress", "conclusion": null,
            "steps": [ { "name": "Compile", "status": "in_progress", "conclusion": null } ] }
        ] }
        """)
        guard case .fresh(let jobs, _) = try await client.fetchJobs(in: "acme/api", run: 9, etag: nil) else {
            Issue.record("Expected fresh jobs")
            return
        }
        #expect(JobProgress(jobs: jobs) == JobProgress(done: 2, total: 3, failed: 1, current: "build"))
        #expect(jobs[1].failedStep == "Run tests")
        #expect(jobs[1].duration(now: .now) == 120)
        #expect(jobs[2].currentStep == "Compile")
        #expect(jobs[1].steps.map(\.state) == [.passed, .failed, .skipped])
        #expect(jobs[1].steps.first?.duration(now: .now) == 5)
        #expect(jobs[1].steps.last?.duration(now: .now) == nil)
        #expect(jobs[2].steps.first?.number == 1)
    }

    @Test func groupsMatrixJobsAndPutsFailuresFirst() {
        let groups = JobGroup.grouping([
            .make(id: 1, name: "lint", state: .passed),
            .make(id: 2, name: "test (ubuntu, 18)", state: .passed),
            .make(id: 3, name: "test (ubuntu, 20)", state: .failed),
            .make(id: 4, name: "build", state: .running),
        ])
        #expect(groups.map(\.name) == ["test", "build", "lint"])
        #expect(groups[0].isMatrix)
        #expect(groups[0].jobs.map(\.id) == [3, 2])
        #expect(groups[0].state == .failed)
    }

    @Test func postsTheRerunAndCancelCommands() async throws {
        let (client, token) = client(status: 201, body: "{}")
        try await client.rerunFailedJobs(in: "acme/api", run: 9)
        let rerun = StubURLProtocol.lastRequest(token: token)
        #expect(rerun?.httpMethod == "POST")
        #expect(rerun?.url?.path() == "/repos/acme/api/actions/runs/9/rerun-failed-jobs")
        try await client.cancelRun(in: "acme/api", run: 9)
        #expect(StubURLProtocol.lastRequest(token: token)?.url?.path() == "/repos/acme/api/actions/runs/9/cancel")
    }

    @Test func readsReposFromRecentPushes() async throws {
        let (client, _) = client(body: """
        [ { "type": "PushEvent", "repo": { "name": "acme/web" } },
          { "type": "WatchEvent", "repo": { "name": "acme/stars" } },
          { "type": "PushEvent", "repo": { "name": "acme/api" } },
          { "type": "PushEvent", "repo": { "name": "acme/web" } } ]
        """)
        #expect(try await client.fetchPushedRepos(login: "me") == ["acme/web", "acme/api"])
    }
}
