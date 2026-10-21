import Foundation

struct WorkflowJob: Identifiable, Equatable {
    let id: Int
    let name: String
    let state: WorkflowRun.State
    let url: URL?
    let startedAt: Date?
    let completedAt: Date?
    let failedStep: String?
    let currentStep: String?

    var group: String {
        guard let open = name.range(of: " ("), name.hasSuffix(")") else { return name }
        return String(name[..<open.lowerBound])
    }

    var isFailed: Bool { state == .failed }

    var rank: Int {
        switch state {
        case .failed: 0
        case .running: 1
        case .waiting: 2
        case .queued: 3
        case .passed: 4
        case .cancelled: 5
        case .skipped: 6
        }
    }

    func duration(now: Date) -> TimeInterval? {
        guard let startedAt else { return nil }
        return (completedAt ?? now).timeIntervalSince(startedAt)
    }
}

struct JobGroup: Identifiable, Equatable {
    let name: String
    let jobs: [WorkflowJob]

    var id: String { name }

    var state: WorkflowRun.State { jobs.min { $0.rank < $1.rank }?.state ?? .queued }

    var isMatrix: Bool { jobs.count > 1 }

    static func grouping(_ jobs: [WorkflowJob]) -> [JobGroup] {
        var order: [String] = []
        var byName: [String: [WorkflowJob]] = [:]
        for job in jobs {
            if byName[job.group] == nil { order.append(job.group) }
            byName[job.group, default: []].append(job)
        }
        let groups = order.map { JobGroup(name: $0, jobs: byName[$0, default: []].sorted { $0.rank < $1.rank }) }
        return groups.enumerated().sorted { lhs, rhs in
            let left = lhs.element.jobs.first?.rank ?? .max
            let right = rhs.element.jobs.first?.rank ?? .max
            return left == right ? lhs.offset < rhs.offset : left < right
        }.map(\.element)
    }
}

extension JobProgress {
    init(jobs: [WorkflowJob]) {
        let done = jobs.filter { !$0.state.isActive }
        self.init(
            done: done.count,
            total: jobs.count,
            failed: done.filter(\.isFailed).count,
            current: jobs.first { $0.state == .running }?.name
        )
    }
}
