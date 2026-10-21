import Foundation

struct RunTab: AccountScoped, Codable, Hashable {
    enum Preset: String, Codable, CaseIterable {
        case mine, everyone, deploys
    }

    enum Starter: String, Codable, CaseIterable {
        case anyone, me, user
    }

    enum Event: String, Codable, CaseIterable {
        case any, push, pullRequest, schedule, manual

        func matches(_ event: String) -> Bool {
            switch self {
            case .any: true
            case .push: event == "push"
            case .pullRequest: event == "pull_request" || event == "pull_request_target"
            case .schedule: event == "schedule"
            case .manual: event == "workflow_dispatch"
            }
        }
    }

    enum Status: String, Codable, CaseIterable {
        case all, active, failing

        func matches(_ run: WorkflowRun) -> Bool {
            switch self {
            case .all: true
            case .active: run.state.isActive
            case .failing: run.state == .failed || (run.jobs?.failed ?? 0) > 0
            }
        }
    }

    var id = UUID()
    var name: String
    var preset: Preset?
    var startedBy: Starter = .anyone
    var user = ""
    var repo = ""
    var workflow = ""
    var branch = ""
    var event: Event = .any
    var status: Status = .all
    var account: String?

    var isComplete: Bool {
        !name.trimmed.isEmpty && (startedBy != .user || !user.trimmed.isEmpty)
    }

    func includes(_ run: WorkflowRun, login: String) -> Bool {
        switch startedBy {
        case .anyone: break
        case .me: guard run.isStarted(by: login) else { return false }
        case .user: guard run.isStarted(by: String(user.trimmed.trimmingPrefix("@"))) else { return false }
        }
        if !repo.trimmed.isEmpty, run.repo.caseInsensitiveCompare(repo.trimmed) != .orderedSame,
           run.repoName.caseInsensitiveCompare(repo.trimmed) != .orderedSame { return false }
        if !workflow.trimmed.isEmpty, !run.workflow.localizedCaseInsensitiveContains(workflow.trimmed) { return false }
        if !branch.trimmed.isEmpty, !Self.branch(run.branch ?? "", matches: branch.trimmed) { return false }
        return event.matches(run.event) && status.matches(run)
    }

    static func branch(_ branch: String, matches pattern: String) -> Bool {
        if pattern.hasSuffix("*") { return branch.hasPrefix(pattern.dropLast()) }
        if pattern.hasSuffix("/") { return branch.hasPrefix(pattern) }
        return branch == pattern
    }
}

extension RunTab {
    static func builtIn(_ preset: Preset) -> RunTab {
        switch preset {
        case .mine: RunTab(name: String(localized: "Mine"), preset: .mine, startedBy: .me)
        case .everyone: RunTab(name: String(localized: "Everyone"), preset: .everyone)
        case .deploys: RunTab(name: String(localized: "Deploys"), preset: .deploys, workflow: "deploy")
        }
    }

    static var defaults: [RunTab] { Preset.allCases.map(builtIn) }

    static var examples: [RunTab] {
        [
            RunTab(name: String(localized: "Production deploys"), workflow: "deploy", branch: "main"),
            RunTab(name: String(localized: "Failing on main"), branch: "main", status: .failing),
            RunTab(name: String(localized: "My failing runs"), startedBy: .me, status: .failing),
            RunTab(name: String(localized: "Pull request checks"), startedBy: .me, event: .pullRequest),
            RunTab(name: String(localized: "Scheduled"), event: .schedule),
            RunTab(name: String(localized: "Manual runs"), event: .manual),
            RunTab(name: String(localized: "Release branches"), branch: "release/*"),
        ]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        preset = try? container.decodeIfPresent(Preset.self, forKey: .preset)
        startedBy = (try? container.decodeIfPresent(Starter.self, forKey: .startedBy)) ?? .anyone
        user = try container.decodeIfPresent(String.self, forKey: .user) ?? ""
        repo = try container.decodeIfPresent(String.self, forKey: .repo) ?? ""
        workflow = try container.decodeIfPresent(String.self, forKey: .workflow) ?? ""
        branch = try container.decodeIfPresent(String.self, forKey: .branch) ?? ""
        event = (try? container.decodeIfPresent(Event.self, forKey: .event)) ?? .any
        status = (try? container.decodeIfPresent(Status.self, forKey: .status)) ?? .all
        account = try container.decodeIfPresent(String.self, forKey: .account)
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension RunTab.Starter {
    var title: String {
        switch self {
        case .anyone: String(localized: "Anyone")
        case .me: String(localized: "Me")
        case .user: String(localized: "Someone else")
        }
    }
}

extension RunTab.Event {
    var title: String {
        switch self {
        case .any: String(localized: "Any")
        case .push: String(localized: "Push")
        case .pullRequest: String(localized: "Pull request")
        case .schedule: String(localized: "Scheduled")
        case .manual: String(localized: "Manual")
        }
    }
}

extension RunTab.Status {
    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .active: String(localized: "Running or waiting")
        case .failing: String(localized: "Failing")
        }
    }
}

extension RunTab {
    var summary: String {
        var parts: [String] = []
        switch startedBy {
        case .anyone: break
        case .me: parts.append(String(localized: "Started by me"))
        case .user: parts.append("@" + String(user.trimmed.trimmingPrefix("@")))
        }
        if !repo.trimmed.isEmpty { parts.append(repo.trimmed) }
        if !workflow.trimmed.isEmpty { parts.append(String(localized: "Workflow “\(workflow.trimmed)”")) }
        if !branch.trimmed.isEmpty { parts.append(branch.trimmed) }
        if event != .any { parts.append(event.title) }
        if status != .all { parts.append(status.title) }
        return parts.isEmpty ? String(localized: "Every run") : parts.joined(separator: " · ")
    }
}
