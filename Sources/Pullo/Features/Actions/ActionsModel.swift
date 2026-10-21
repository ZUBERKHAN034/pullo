import Observation
import OSLog
import SwiftUI

@MainActor
@Observable
final class ActionsModel {
    static let recentLimit = 15

    enum Command: Equatable {
        case rerunFailedJobs, cancel
    }

    private var chosenTabID: RunTab.ID?
    private(set) var openedRunID: Int?
    private(set) var running: Command?

    let store: RunStore
    private let list: PRListModel
    private let accounts: AccountStore

    init(store: RunStore, list: PRListModel, accounts: AccountStore) {
        self.store = store
        self.list = list
        self.accounts = accounts
    }

    var tabs: [RunTab] { list.currentLogin.map(accounts.runTabs(for:)) ?? [] }

    var tab: RunTab? { tabs.first { $0.id == chosenTabID } ?? tabs.first }

    var isLoaded: Bool { store.isLoaded(list.currentLogin) }

    var problem: RefreshProblem? { list.currentLogin.flatMap { store.errors[$0] } }

    func runs(in tab: RunTab?) -> [WorkflowRun] {
        guard let login = list.currentLogin, let tab else { return [] }
        return store.runs(for: login).filter { tab.includes($0, login: login) }
    }

    var active: [WorkflowRun] { runs(in: tab).filter(\.state.isActive) }

    var recent: [WorkflowRun] {
        Array(runs(in: tab).filter { !$0.state.isActive }.sorted { $0.updatedAt > $1.updatedAt }.prefix(Self.recentLimit))
    }

    func activeCount(in tab: RunTab) -> Int {
        runs(in: tab).filter(\.state.isActive).count
    }

    var myActiveCount: Int {
        guard let login = list.currentLogin else { return 0 }
        return store.runs(for: login).filter { $0.state.isActive && $0.isStarted(by: login) }.count
    }

    func select(_ tab: RunTab) {
        withAnimation(Motion.navigate) { chosenTabID = tab.id }
    }

    // MARK: - Run detail

    var openedRun: WorkflowRun? {
        guard let openedRunID else { return nil }
        return store.runs(for: list.currentLogin).first { $0.id == openedRunID }
    }

    var openedJobs: [WorkflowJob]? { openedRunID.flatMap { store.jobs[$0] } }

    var openedJobsError: String? { openedRunID.flatMap { store.jobErrors[$0] } }

    func open(_ run: WorkflowRun) {
        store.watchedRun = run.id
        withAnimation(Motion.navigate) { openedRunID = run.id }
        Task { await store.loadJobs(of: run) }
    }

    @discardableResult
    func back() -> Bool {
        guard openedRunID != nil else { return false }
        store.watchedRun = nil
        withAnimation(Motion.navigate) { openedRunID = nil }
        return true
    }

    func perform(_ command: Command) async {
        guard running == nil, let run = openedRun else { return }
        running = command
        defer { running = nil }
        do {
            switch command {
            case .rerunFailedJobs:
                try await store.rerunFailedJobs(of: run)
                list.showToast(String(localized: "Re-running the failed jobs"))
            case .cancel:
                try await store.cancel(run)
                list.showToast(String(localized: "Cancelling the run"))
            }
        } catch {
            Logger.store.error("Run command failed: \(error.localizedDescription, privacy: .public)")
            switch command {
            case .rerunFailedJobs: list.showToast(String(localized: "Couldn't re-run the jobs"))
            case .cancel: list.showToast(String(localized: "Couldn't cancel the run"))
            }
        }
    }
}
