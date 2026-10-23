import Foundation

struct WorkflowRun: Identifiable, Equatable {
    enum State: Equatable {
        case queued, waiting, running, passed, failed, cancelled, skipped

        var isActive: Bool { self == .queued || self == .waiting || self == .running }
    }

    let id: Int
    let account: String
    let repo: String
    let workflow: String
    let title: String
    let branch: String?
    let event: String
    let state: State
    let url: URL
    let actor: String?
    let triggeringActor: String?
    let createdAt: Date
    let startedAt: Date
    let updatedAt: Date
    let pullRequest: Int?
    var jobs: JobProgress?

    var repoName: String { repo.split(separator: "/").last.map(String.init) ?? repo }

    func isStarted(by login: String) -> Bool {
        actor?.caseInsensitiveCompare(login) == .orderedSame || triggeringActor?.caseInsensitiveCompare(login) == .orderedSame
    }

    static func state(status: String, conclusion: String?) -> State {
        switch status {
        case "in_progress": return .running
        case "waiting", "action_required": return .waiting
        case "completed": break
        default: return .queued
        }
        switch conclusion {
        case "success", "neutral": return .passed
        case "cancelled": return .cancelled
        case "skipped", "stale": return .skipped
        case "action_required": return .waiting
        default: return .failed
        }
    }
}

struct JobProgress: Equatable {
    let done: Int
    let total: Int
    let failed: Int
    let current: String?

    var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
}
