@testable import DevNotch
import Foundation
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
          { "name": "lint", "status": "completed", "conclusion": "success" },
          { "name": "test", "status": "completed", "conclusion": "failure" },
          { "name": "build", "status": "in_progress", "conclusion": null }
        ] }
        """)
        guard case .fresh(let jobs, _) = try await client.fetchJobs(in: "acme/api", run: 9, etag: nil) else {
            Issue.record("Expected fresh jobs")
            return
        }
        #expect(jobs == JobProgress(done: 2, total: 3, failed: 1, current: "build"))
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
