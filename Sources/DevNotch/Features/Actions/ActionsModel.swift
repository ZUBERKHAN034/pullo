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

    private(set) var filter: RunFilter = .mine
    private(set) var openedRunID: Int?
    private(set) var running: Command?

    let store: RunStore
    private let list: PRListModel

    init(store: RunStore, list: PRListModel) {
        self.store = store
        self.list = list
    }

    var isLoaded: Bool { store.isLoaded(list.currentLogin) }

    var error: String? { list.currentLogin.flatMap { store.errors[$0] } }

    func runs(in filter: RunFilter) -> [WorkflowRun] {
        guard let login = list.currentLogin else { return [] }
        return store.runs(for: login).filter { filter.includes($0, login: login) }
    }

    var active: [WorkflowRun] { runs(in: filter).filter(\.state.isActive) }

    var recent: [WorkflowRun] {
        Array(runs(in: filter).filter { !$0.state.isActive }.sorted { $0.updatedAt > $1.updatedAt }.prefix(Self.recentLimit))
    }

    func activeCount(in filter: RunFilter) -> Int {
        runs(in: filter).filter(\.state.isActive).count
    }

    func select(_ filter: RunFilter) {
        withAnimation(Motion.navigate) { self.filter = filter }
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
