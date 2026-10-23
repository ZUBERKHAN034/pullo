import Foundation

@MainActor
final class LiveCIModel {
    private struct Inputs: Equatable {
        let prRevision: Int
        let runRevision: Int
        let logins: [String]
    }

    private let prs: PRStore
    private let runs: RunStore
    private let accounts: AccountStore
    private let settings: AppSettings
    private let peeks: PeekPresenter
    private var cached: (inputs: Inputs, running: LiveCI?)?

    init(prs: PRStore, runs: RunStore, accounts: AccountStore, settings: AppSettings, peeks: PeekPresenter) {
        self.prs = prs
        self.runs = runs
        self.accounts = accounts
        self.settings = settings
        self.peeks = peeks
    }

    var current: LiveCI? {
        guard settings.showsLiveCI, var live = peeks.finishedCI ?? running else { return nil }
        live.label = settings.liveCILabel
        return live
    }

    private var running: LiveCI? {
        let logins = accounts.logins.filter { !settings.mutedAccounts.contains($0) }
        let inputs = Inputs(prRevision: prs.revision, runRevision: runs.revision, logins: logins)
        if let cached, cached.inputs == inputs { return cached.running }
        let running = Self.running(prs: prs.runningCI(for: logins), runs: runs, logins: logins)
        cached = (inputs, running)
        return running
    }

    private static func running(prs: [PullRequest], runs: RunStore, logins: [String]) -> LiveCI? {
        let prKeys = Set(prs.map { "\($0.repo.lowercased())#\($0.number)" })
        let ownRuns = logins.flatMap { login in
            runs.runs(for: login).filter { $0.state == .running && $0.isStarted(by: login) }
        }
        .filter { run in run.pullRequest.map { !prKeys.contains("\(run.repo.lowercased())#\($0)") } ?? true }
        let candidates = prs.map { (LiveCI(pr: $0), $0.updatedAt) } + ownRuns.map { (LiveCI(run: $0), $0.startedAt) }
        guard var live = candidates.max(by: { $0.1 < $1.1 })?.0 else { return nil }
        live.othersRunning = candidates.count - 1
        return live
    }
}
