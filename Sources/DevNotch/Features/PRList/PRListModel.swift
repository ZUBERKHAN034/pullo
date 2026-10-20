import Observation
import SwiftUI

@MainActor
@Observable
final class PRListModel {
    private(set) var tab: PRTab = .mine
    private(set) var selectedLogin: String?
    private(set) var selectedPRID: String?
    var keyboardMode = false
    private(set) var toast: String?
    private(set) var isSearching = false
    var searchQuery = "" {
        didSet { if isSearching { selectedPRID = visiblePRs.first?.id } }
    }

    @ObservationIgnored var onNeedsKeyFocus: (() -> Void)?

    private let store: PRStore
    private let accounts: AccountStore
    private let tracker: ReadTracker
    private let system: any SystemActions
    private let clock: any Clock<Duration>
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(
        store: PRStore,
        accounts: AccountStore,
        tracker: ReadTracker,
        system: any SystemActions,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.store = store
        self.accounts = accounts
        self.tracker = tracker
        self.system = system
        self.clock = clock
    }

    var currentLogin: String? {
        if let selectedLogin, accounts.accounts.contains(where: { $0.login == selectedLogin }) {
            return selectedLogin
        }
        return accounts.accounts.first?.login
    }

    func prs(in tab: PRTab) -> [PullRequest] {
        tab == .mine ? store.mine(for: currentLogin) : store.reviewRequests(for: currentLogin)
    }

    var visiblePRs: [PullRequest] {
        guard isSearching else { return prs(in: tab) }
        var seen = Set<String>()
        return (prs(in: .mine) + prs(in: .review)).filter { $0.matches(searchQuery) && seen.insert($0.id).inserted }
    }

    var selectedPR: PullRequest? {
        visiblePRs.first { $0.id == selectedPRID }
    }

    func selectTab(_ tab: PRTab) {
        withAnimation(Motion.navigate) { self.tab = tab }
        resetSelection()
    }

    func selectAccount(_ login: String) {
        withAnimation(Motion.navigate) { selectedLogin = login }
        resetSelection()
    }

    func selectAccount(number: Int) -> Bool {
        guard accounts.accounts.indices.contains(number - 1) else { return false }
        selectAccount(accounts.accounts[number - 1].login)
        return true
    }

    func startSearch() {
        keyboardMode = true
        onNeedsKeyFocus?()
        withAnimation(Motion.navigate) { isSearching = true }
        selectedPRID = visiblePRs.first?.id
    }

    func stopSearch() {
        withAnimation(Motion.navigate) {
            isSearching = false
            searchQuery = ""
        }
        resetSelection()
    }

    func moveSelection(by delta: Int) {
        let prs = visiblePRs
        guard !prs.isEmpty else { return }
        let current = prs.firstIndex { $0.id == selectedPRID }
        let next = current.map { min(max($0 + delta, 0), prs.count - 1) } ?? 0
        selectedPRID = prs[next].id
    }

    func selectFirstIfNeeded() {
        if selectedPR == nil { selectedPRID = visiblePRs.first?.id }
    }

    func reset() {
        keyboardMode = false
        selectedPRID = nil
        isSearching = false
        searchQuery = ""
    }

    func markRead(_ pr: PullRequest) {
        tracker.markRead([pr])
    }

    func markAllRead() {
        tracker.markRead(visiblePRs)
        showToast("All marked as read")
    }

    func copyBranch(_ pr: PullRequest) {
        system.copy(pr.branch)
        showToast("Copied branch: \(pr.branch)")
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(Motion.navigate) { toast = message }
        let clock = clock
        toastTask = Task { [weak self] in
            try? await clock.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.fade) { self?.toast = nil }
        }
    }

    private func resetSelection() {
        guard selectedPRID != nil || keyboardMode else { return }
        selectedPRID = visiblePRs.first?.id
    }
}
