import AppKit
import SwiftUI

/// Drives the notch: which state it's in, what the panel shows, alerts waiting to drop out, and input.
@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var state: NotchState = .closed
    @Published private(set) var peekAlert: NotchAlert?
    @Published private(set) var tab: PRTab = .mine
    @Published private(set) var screen: PanelScreen = .prs
    @Published private(set) var selectedLogin: String?
    @Published var geometry: NotchGeometry
    /// PR highlighted by keyboard navigation.
    @Published private(set) var selectedPRID: String?
    /// Opened from the shortcut: stays open until Esc, the shortcut again, or a click outside.
    @Published private(set) var keyboardMode = false
    @Published private(set) var toast: String?
    @Published private(set) var isSearching = false
    @Published var searchQuery = "" {
        didSet { if isSearching { selectedPRID = visiblePRs.first?.id } }
    }

    let store: PRStore
    let accounts: AccountStore
    let settings: AppSettings
    let tracker: ReadTracker

    /// The panel needs key focus for typing (search); AppKit-side, so the delegate provides it.
    var onNeedsKeyFocus: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private var queue: [NotchAlert] = []
    private var peekTask: Task<Void, Never>?
    private var hoverTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    /// Set after closing while the pointer is still over the notch, so it doesn't spring right back open.
    private var waitingForPointerExit = false
    /// The pointer is over the peek, so it stays out until the pointer leaves.
    private var holdingPeek = false

    init(store: PRStore, accounts: AccountStore, settings: AppSettings, tracker: ReadTracker, geometry: NotchGeometry) {
        self.store = store
        self.accounts = accounts
        self.settings = settings
        self.tracker = tracker
        self.geometry = geometry
    }

    var layout: NotchLayout { NotchLayout(geometry: geometry) }

    /// The account whose PRs the panel shows; falls back to the first one if the selection was removed.
    var currentLogin: String? {
        if let selectedLogin, accounts.accounts.contains(where: { $0.login == selectedLogin }) {
            return selectedLogin
        }
        return accounts.accounts.first?.login
    }

    func prs(in tab: PRTab) -> [PullRequest] {
        tab == .mine ? store.mine(for: currentLogin) : store.reviewRequests(for: currentLogin)
    }

    /// What the list shows, in display order: the current tab, or search results across both tabs.
    var visiblePRs: [PullRequest] {
        guard isSearching else { return prs(in: tab) }
        var seen = Set<String>()
        return (prs(in: .mine) + prs(in: .review)).filter { $0.matches(searchQuery) && seen.insert($0.id).inserted }
    }

    // MARK: - Pointer

    func mouseMoved(to point: NSPoint) {
        let inside = layout.hitRect(for: state).contains(point)

        if waitingForPointerExit {
            if !inside { waitingForPointerExit = false }
            return
        }

        switch state {
        case .peek:
            // Hovering holds the alert so it can be clicked; leaving lets it go after a moment.
            if inside {
                guard !holdingPeek else { return }
                holdingPeek = true
                peekTask?.cancel()
            } else if holdingPeek {
                holdingPeek = false
                dismissPeek(after: .seconds(1.5))
            }
        case .closed:
            guard inside else { return cancelHover() }
            scheduleHover(after: .milliseconds(80)) { model in
                if model.layout.hitRect(for: model.state).contains(NSEvent.mouseLocation) { model.open() }
            }
        case .open:
            if keyboardMode {
                // Once the pointer comes over, it's a regular hover panel again.
                if inside { keyboardMode = false }
                return
            }
            guard !inside else { return cancelHover() }
            scheduleHover(after: .milliseconds(200)) { model in
                if !model.layout.hitRect(for: .open).contains(NSEvent.mouseLocation) { model.close() }
            }
        }
    }

    func mouseDown(at point: NSPoint) {
        if state == .open, !layout.hitRect(for: .open).contains(point) { close() }
    }

    /// Waits a beat before reacting to the pointer, so passing over the notch doesn't flicker it.
    private func scheduleHover(after delay: Duration, _ action: @escaping (NotchViewModel) -> Void) {
        guard hoverTask == nil else { return }
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            hoverTask = nil
            action(self)
        }
    }

    private func cancelHover() {
        hoverTask?.cancel()
        hoverTask = nil
    }

    // MARK: - Transitions

    func open(viaKeyboard: Bool = false) {
        peekTask?.cancel()
        holdingPeek = false
        queue.removeAll()
        keyboardMode = viaKeyboard
        if viaKeyboard, selectedPR == nil { selectedPRID = visiblePRs.first?.id }
        withAnimation(Motion.open) {
            state = .open
            peekAlert = nil
        }
    }

    func toggleFromKeyboard() {
        if state == .open { close() } else { open(viaKeyboard: true) }
    }

    /// `pointerStaysOver` is for closes triggered from inside the panel, e.g. clicking a PR.
    func close(pointerStaysOver: Bool = false) {
        cancelHover()
        peekTask?.cancel()
        holdingPeek = false
        waitingForPointerExit = pointerStaysOver
        keyboardMode = false
        selectedPRID = nil
        isSearching = false
        searchQuery = ""
        screen = .prs
        withAnimation(Motion.close) { state = .closed }
    }

    // MARK: - Alerts

    func enqueue(_ alerts: [NotchAlert]) {
        guard state != .open, !alerts.isEmpty else { return }
        queue += alerts
        if state == .closed { showNextPeek() }
    }

    func enqueue(_ alert: NotchAlert) {
        enqueue([alert])
    }

    func enqueue(events: [PREvent]) {
        let showAccount = accounts.accounts.count > 1
        enqueue(events.filter(settings.allows).map { $0.alert(showingAccount: showAccount) })
    }

    func accountConnected(_ account: Account) {
        screen = .prs
        selectedLogin = account.login
        enqueue(NotchAlert(
            symbol: "person.crop.circle.badge.checkmark",
            tint: .green,
            headline: "Account connected",
            detail: "@\(account.login) · loading your PRs"
        ))
    }

    /// Fires one to three sample alerts so the single and stacked peeks can both be seen.
    func previewAlert() {
        close(pointerStaysOver: true)
        let prs = visiblePRs.isEmpty ? [PullRequest.sample] : visiblePRs
        let events = (0..<Int.random(in: 1...3)).map { _ in
            let pr = prs.randomElement() ?? .sample
            let kind = PREvent.Kind.allCases.randomElement() ?? .approved
            return PREvent(kind: kind, pr: pr, actor: kind == .reviewRequested ? pr.author : "octocat")
        }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard let self else { return }
            enqueue(events.map { $0.alert(showingAccount: self.accounts.accounts.count > 1) })
        }
    }

    func tapPeek(_ alert: NotchAlert) {
        if let pr = alert.pr {
            open(pr)
        } else if let url = alert.url {
            openInBrowser(url)
        } else {
            open()
        }
    }

    /// Several alerts waiting at once drop out together as one stacked peek.
    private func showNextPeek() {
        guard state == .closed, !queue.isEmpty else { return }
        let alert = queue.count > 1 ? NotchAlert.summary(of: queue) : queue[0]
        queue.removeAll()
        withAnimation(Motion.peek) {
            peekAlert = alert
            state = .peek
        }
        if settings.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        settings.playSound()
        dismissPeek(after: .seconds(alert.stack.isEmpty ? 4.5 : 6))
    }

    private func dismissPeek(after delay: Duration) {
        peekTask?.cancel()
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, state == .peek else { return }
            withAnimation(Motion.close) { self.state = .closed }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            showNextPeek()
        }
    }

    // MARK: - Panel actions

    func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
        close(pointerStaysOver: true)
    }

    /// Opening a PR is what marks it as read.
    func open(_ pr: PullRequest) {
        tracker.markRead([pr])
        openInBrowser(pr.url)
    }

    func markRead(_ pr: PullRequest) {
        tracker.markRead([pr])
    }

    func markAllRead() {
        tracker.markRead(visiblePRs)
        showToast("All marked as read")
    }

    func copyBranch(_ pr: PullRequest) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pr.branch, forType: .string)
        showToast("Copied branch: \(pr.branch)")
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(Motion.navigate) { toast = message }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.fade) { self?.toast = nil }
        }
    }

    /// Toggles a secondary screen; showing the one already up goes back to the list.
    func show(_ screen: PanelScreen) {
        withAnimation(Motion.navigate) {
            self.screen = self.screen == screen ? .prs : screen
        }
    }

    func selectTab(_ tab: PRTab) {
        withAnimation(Motion.navigate) { self.tab = tab }
        resetSelection()
    }

    func selectAccount(_ login: String) {
        withAnimation(Motion.navigate) {
            selectedLogin = login
            screen = .prs
        }
        resetSelection()
    }

    func startSearch() {
        keyboardMode = true
        onNeedsKeyFocus?()
        withAnimation(Motion.navigate) {
            screen = .prs
            isSearching = true
        }
        selectedPRID = visiblePRs.first?.id
    }

    func stopSearch() {
        withAnimation(Motion.navigate) {
            isSearching = false
            searchQuery = ""
        }
        resetSelection()
    }

    // MARK: - Keyboard

    /// Returns whether the key was used, so unused keys keep flowing to the focused field or app.
    func handleKey(_ event: NSEvent) -> Bool {
        guard state == .open, let command = KeyCommand(
            keyCode: Int(event.keyCode),
            characters: event.charactersIgnoringModifiers ?? "",
            command: event.modifierFlags.contains(.command),
            searching: isSearching
        ) else { return false }
        return perform(command)
    }

    private func perform(_ command: KeyCommand) -> Bool {
        switch command {
        case .quit:
            NSApp.terminate(nil)
        case .search:
            startSearch()
        case .close:
            if isSearching { stopSearch() } else if screen == .prs { close() } else { show(screen) }
        default:
            guard screen == .prs else { return false }
            return performListCommand(command)
        }
        return true
    }

    private func performListCommand(_ command: KeyCommand) -> Bool {
        switch command {
        case .moveUp: moveSelection(by: -1)
        case .moveDown: moveSelection(by: 1)
        case .switchTab: selectTab(tab == .mine ? .review : .mine)
        case .selectAccount(let number):
            guard number <= accounts.accounts.count else { return false }
            selectAccount(accounts.accounts[number - 1].login)
        case .open, .copyBranch, .markRead:
            guard let pr = selectedPR else { return false }
            switch command {
            case .open: open(pr)
            case .copyBranch: copyBranch(pr)
            default: markRead(pr)
            }
        case .quit, .search, .close:
            return false
        }
        return true
    }

    private var selectedPR: PullRequest? {
        visiblePRs.first { $0.id == selectedPRID }
    }

    private func moveSelection(by delta: Int) {
        let prs = visiblePRs
        guard !prs.isEmpty else { return }
        let current = prs.firstIndex { $0.id == selectedPRID }
        let next = current.map { min(max($0 + delta, 0), prs.count - 1) } ?? 0
        selectedPRID = prs[next].id
    }

    /// After the list changes, keyboard users land on its first PR; pointer users don't get a selection.
    private func resetSelection() {
        guard selectedPRID != nil || keyboardMode else { return }
        selectedPRID = visiblePRs.first?.id
    }
}
