import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class NotchInteraction {
    private(set) var state: NotchState = .closed {
        didSet { onStateChange?(state) }
    }

    private(set) var peekAlert: NotchAlert?
    private(set) var area: PanelArea = .pullRequests
    var geometry: NotchGeometry

    let list: PRListModel
    private let runs: RunStore
    private let accounts: AccountStore
    private let settings: AppSettings
    private let system: any SystemActions
    private let clock: any Clock<Duration>

    @ObservationIgnored var onStateChange: ((NotchState) -> Void)?
    @ObservationIgnored var onOpenSettings: ((SettingsPage?) -> Void)?
    @ObservationIgnored var actions: ActionsModel?

    @ObservationIgnored private var alerts = AlertQueue()
    @ObservationIgnored private var peekTask: Task<Void, Never>?
    @ObservationIgnored private var hoverTask: Task<Void, Never>?
    @ObservationIgnored private var waitingForPointerExit = false
    @ObservationIgnored private var holdingPeek = false
    @ObservationIgnored private var pointer: NSPoint?
    @ObservationIgnored private var buttonHeld = false
    @ObservationIgnored private var missedDuringFocus: [NotchAlert] = []
    @ObservationIgnored private var focusWatch: Task<Void, Never>?
    @ObservationIgnored private var finishedCITask: Task<Void, Never>?
    private var finishedCI: LiveCI?

    init(
        list: PRListModel,
        runs: RunStore,
        accounts: AccountStore,
        settings: AppSettings,
        system: any SystemActions,
        geometry: NotchGeometry,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.list = list
        self.runs = runs
        self.accounts = accounts
        self.settings = settings
        self.system = system
        self.geometry = geometry
        self.clock = clock
    }

    var layout: NotchLayout { NotchLayout(geometry: geometry, closedWings: liveCI?.wingWidth ?? 0) }

    var liveCI: LiveCI? {
        guard geometry.hasNotch, settings.showsLiveCI else { return nil }
        if var finishedCI {
            finishedCI.label = settings.liveCILabel
            return finishedCI
        }
        let logins = accounts.accounts.map(\.login).filter { !settings.mutedAccounts.contains($0) }
        let prs = list.store.runningCI(for: logins)
        let prKeys = Set(prs.map { "\($0.repo.lowercased())#\($0.number)" })
        let ownRuns = logins.flatMap { login in
            runs.runs(for: login).filter { $0.state == .running && $0.isStarted(by: login) }
        }
        .filter { run in run.pullRequest.map { !prKeys.contains("\(run.repo.lowercased())#\($0)") } ?? true }
        let candidates = prs.map { (LiveCI(pr: $0), $0.updatedAt) } + ownRuns.map { (LiveCI(run: $0), $0.startedAt) }
        guard var live = candidates.max(by: { $0.1 < $1.1 })?.0 else { return nil }
        live.othersRunning = candidates.count - 1
        live.label = settings.liveCILabel
        return live
    }

    // MARK: - Pointer

    func mouseMoved(to point: NSPoint, buttonHeld: Bool = false) {
        pointer = point
        self.buttonHeld = buttonHeld
        let inside = layout.hitRect(for: state).contains(point)

        if waitingForPointerExit {
            if !inside { waitingForPointerExit = false }
            return
        }

        switch state {
        case .peek:
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
            scheduleHover(after: .milliseconds(80)) { notch in
                if notch.isPointerOver(notch.state) { notch.open() }
            }
        case .open:
            if list.keyboardMode {
                if inside { list.keyboardMode = false }
                return
            }
            guard !inside, !buttonHeld else { return cancelHover() }
            scheduleHover(after: .milliseconds(200)) { notch in
                if !notch.isPointerOver(.open), !notch.buttonHeld { notch.close() }
            }
        }
    }

    func mouseDown(at point: NSPoint) {
        if state == .open, !layout.hitRect(for: .open).contains(point) { close() }
    }

    private func scheduleHover(after delay: Duration, _ action: @escaping (NotchInteraction) -> Void) {
        guard hoverTask == nil else { return }
        let clock = clock
        hoverTask = Task { [weak self] in
            try? await clock.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            hoverTask = nil
            action(self)
        }
    }

    private func isPointerOver(_ state: NotchState) -> Bool {
        pointer.map(layout.hitRect(for: state).contains) ?? false
    }

    private func cancelHover() {
        hoverTask?.cancel()
        hoverTask = nil
    }

    // MARK: - Transitions

    func open(viaKeyboard: Bool = false) {
        peekTask?.cancel()
        holdingPeek = false
        alerts.removeAll()
        forgetMissedAlerts()
        list.keyboardMode = viaKeyboard
        if viaKeyboard { list.selectFirstIfNeeded() }
        withAnimation(Motion.open) {
            state = .open
            peekAlert = nil
        }
    }

    func toggleFromKeyboard() {
        if state == .open { close() } else { open(viaKeyboard: true) }
    }

    func close(pointerStaysOver: Bool = false) {
        cancelHover()
        peekTask?.cancel()
        holdingPeek = false
        waitingForPointerExit = pointerStaysOver
        list.reset()
        withAnimation(Motion.close) { state = .closed }
    }

    func show(_ area: PanelArea) {
        guard area != self.area else { return }
        if list.isSearching { list.stopSearch() }
        withAnimation(Motion.navigate) { self.area = area }
    }

    // MARK: - Alerts

    func enqueue(_ alerts: [NotchAlert]) {
        guard state != .open, !alerts.isEmpty else { return }
        self.alerts.append(alerts)
        if state == .closed { showNextPeek() }
    }

    func enqueue(_ alert: NotchAlert) {
        enqueue([alert])
    }

    func enqueue(events: [PREvent]) {
        let shown = events.filter(settings.allows)
        let alerts = shown.map { $0.alert(showingAccount: showsAccounts) }
        guard let finished = shown.first(where: { $0.kind == .ciFailed }) ?? shown.first(where: { $0.kind == .ciPassed }),
              showsFinishedCI(on: finished.pr)
        else { return enqueue(alerts) }
        showFinishedCI(finished.pr, then: alerts)
    }

    private func showsFinishedCI(on pr: PullRequest) -> Bool {
        state == .closed && finishedCITask == nil && geometry.hasNotch && settings.showsLiveCI
            && !settings.mutedAccounts.contains(pr.account)
    }

    func runsFinished(_ finished: [WorkflowRun]) {
        let shown = finished.filter { !settings.mutedAccounts.contains($0.account) }
        guard let run = shown.first(where: { $0.state == .failed }) ?? shown.first(where: { $0.state == .passed }),
              state == .closed, finishedCITask == nil, geometry.hasNotch, settings.showsLiveCI
        else { return }
        flash(LiveCI(run: run, finished: run.state == .failed ? .failure : .success), then: [])
    }

    private func showFinishedCI(_ pr: PullRequest, then alerts: [NotchAlert]) {
        flash(LiveCI(pr: pr, finished: pr.ci), then: alerts)
    }

    private func flash(_ live: LiveCI, then alerts: [NotchAlert]) {
        finishedCI = live
        let clock = clock
        finishedCITask = Task { [weak self] in
            try? await clock.sleep(for: .seconds(2))
            guard let self else { return }
            finishedCI = nil
            finishedCITask = nil
            enqueue(alerts)
        }
    }

    func accountConnected(_ account: Account) {
        list.selectAccount(account.login)
        enqueue(NotchAlert(
            symbol: "person.crop.circle.badge.checkmark",
            tint: .green,
            headline: String(localized: "Account connected"),
            detail: String(localized: "@\(account.login) · loading your PRs")
        ))
    }

    func previewAlert() {
        close(pointerStaysOver: true)
        let prs = list.visiblePRs.isEmpty ? [PullRequest.sample] : list.visiblePRs
        let events = (0..<Int.random(in: 1...3)).map { _ in
            let pr = prs.randomElement() ?? .sample
            let kind = PREvent.Kind.allCases.randomElement() ?? .approved
            return PREvent(kind: kind, pr: pr, actor: kind == .reviewRequested ? pr.author : "octocat")
        }
        let clock = clock
        Task { [weak self] in
            try? await clock.sleep(for: .milliseconds(450))
            guard let self, state == .closed else { return }
            alerts.append(events.map { $0.alert(showingAccount: self.showsAccounts) })
            showNextPeek(evenInFocus: true)
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

    private var showsAccounts: Bool {
        accounts.accounts.count > 1
    }

    private func showNextPeek(evenInFocus: Bool = false) {
        guard state == .closed, let alert = alerts.next() else { return }
        if !evenInFocus, system.isInFocus {
            holdUntilFocusEnds(alert)
            return
        }
        withAnimation(Motion.peek) {
            peekAlert = alert
            state = .peek
        }
        if settings.haptics { system.tapTrackpad() }
        if let sound = settings.sound(for: alert.category) { system.play(sound: sound) }
        dismissPeek(after: AlertQueue.displayTime(for: alert))
    }

    private func holdUntilFocusEnds(_ alert: NotchAlert) {
        missedDuringFocus += alert.stack.isEmpty ? [alert] : alert.stack
        guard focusWatch == nil else { return }
        let clock = clock
        focusWatch = Task { [weak self] in
            while !Task.isCancelled {
                try? await clock.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                if !system.isInFocus {
                    showMissedAlerts()
                    return
                }
            }
        }
    }

    private func showMissedAlerts() {
        focusWatch = nil
        guard !missedDuringFocus.isEmpty else { return }
        alerts.append([NotchAlert.summary(of: missedDuringFocus, note: String(localized: "While you were in Focus"))])
        missedDuringFocus.removeAll()
        if state == .closed { showNextPeek() }
    }

    private func forgetMissedAlerts() {
        focusWatch?.cancel()
        focusWatch = nil
        missedDuringFocus.removeAll()
    }

    private func dismissPeek(after delay: Duration) {
        peekTask?.cancel()
        let clock = clock
        peekTask = Task { [weak self] in
            try? await clock.sleep(for: delay)
            guard let self, !Task.isCancelled, state == .peek else { return }
            withAnimation(Motion.close) { self.state = .closed }
            try? await clock.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            showNextPeek()
        }
    }

    // MARK: - Opening

    func openInBrowser(_ url: URL) {
        system.open(url)
        close(pointerStaysOver: true)
    }

    func open(_ pr: PullRequest) {
        list.markRead(pr)
        openInBrowser(pr.url)
    }

    // MARK: - Keyboard

    func handleKey(_ event: NSEvent) -> Bool {
        guard state == .open, let command = KeyCommand(
            keyCode: Int(event.keyCode),
            characters: event.charactersIgnoringModifiers ?? "",
            command: event.modifierFlags.contains(.command),
            searching: list.isSearching
        ) else { return false }
        return perform(command)
    }

    func perform(_ command: KeyCommand) -> Bool {
        if area == .actions, !command.worksEverywhere { return false }
        switch command {
        case .quit: system.quit()
        case .search: list.startSearch()
        case .close:
            if area == .actions, actions?.back() == true { break }
            if list.isSearching { list.stopSearch() } else { close() }
        case .moveUp: list.moveSelection(by: -1)
        case .moveDown: list.moveSelection(by: 1)
        case .switchTab: list.selectTab(by: 1)
        case .previousTab: list.selectTab(by: -1)
        case .selectAccount(let number): return list.selectAccount(number: number)
        case .show(let area): show(area)
        case .open, .copyBranch, .markRead:
            guard let pr = list.selectedPR else { return false }
            switch command {
            case .open: open(pr)
            case .copyBranch: list.copyBranch(pr)
            default: list.markRead(pr)
            }
        }
        return true
    }
}
