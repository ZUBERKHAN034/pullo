import Observation
import SwiftUI

@MainActor
@Observable
final class PRListModel {
    private var chosenTab: PRTab?
    private(set) var selectedLogin: String?
    private(set) var selectedPRID: String?
    var keyboardMode = false
    private(set) var toast: String?
    private(set) var isSearching = false
    var searchQuery = "" {
        didSet { if isSearching { selectedPRID = visiblePRs.first?.id } }
    }

    @ObservationIgnored var onNeedsKeyFocus: (() -> Void)?

    let store: PRStore
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

    var filters: [SavedFilter] {
        currentLogin.map(accounts.filters(for:)) ?? []
    }

    var tabs: [PRTab] {
        filters.map { .filter($0.id) }
    }

    var tab: PRTab {
        let tabs = tabs
        if let chosenTab, tabs.contains(chosenTab) { return chosenTab }
        return tabs.first ?? .mine
    }

    func filter(of tab: PRTab) -> SavedFilter? {
        guard case .filter(let id) = tab else { return nil }
        return filters.first { $0.id == id }
    }

    func preset(of tab: PRTab) -> SavedFilter.Preset? {
        switch tab {
        case .mine: .mine
        case .review: .review
        case .filter: filter(of: tab)?.preset
        }
    }

    func title(of tab: PRTab) -> String {
        filter(of: tab)?.name ?? preset(of: tab)?.name ?? ""
    }

    func filterError(in tab: PRTab) -> String? {
        guard case .filter(let id) = tab else { return nil }
        return store.filterError(id, for: currentLogin)
    }

    func prs(in tab: PRTab) -> [PullRequest] {
        switch tab {
        case .mine: store.mine(for: currentLogin)
        case .review: store.reviewRequests(for: currentLogin)
        case .filter(let id):
            switch filter(of: tab) {
            case let filter? where filter.usesBuiltInSearch:
                filter.preset == .mine ? store.mine(for: currentLogin) : store.reviewRequests(for: currentLogin)
            default:
                store.filtered(id, for: currentLogin)
            }
        }
    }

    var visiblePRs: [PullRequest] {
        guard isSearching else { return prs(in: tab) }
        var seen = Set<String>()
        return (tabs + [.mine, .review]).flatMap(prs(in:)).filter { $0.matches(searchQuery) && seen.insert($0.id).inserted }
    }

    var selectedPR: PullRequest? {
        visiblePRs.first { $0.id == selectedPRID }
    }

    func selectTab(_ tab: PRTab) {
        withAnimation(Motion.navigate) { chosenTab = tab }
        resetSelection()
    }

    func selectTab(by offset: Int) {
        let tabs = tabs
        guard let index = tabs.firstIndex(of: tab) else { return }
        selectTab(tabs[(index + offset + tabs.count) % tabs.count])
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
        showToast(String(localized: "All marked as read"))
    }

    func copyBranch(_ pr: PullRequest) {
        system.copy(pr.branch)
        showToast(String(localized: "Copied branch: \(pr.branch)"))
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
