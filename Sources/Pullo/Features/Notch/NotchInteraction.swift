import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class NotchInteraction {
    private(set) var state: NotchState = .closed {
        didSet {
            runs.setPanelOpen(state == .open)
            onStateChange?(state)
        }
    }

    private(set) var area: PanelArea = .pullRequests
    var geometry: NotchGeometry

    let list: PRListModel
    let peeks: PeekPresenter
    private let actions: ActionsModel
    private let liveCIModel: LiveCIModel
    private let runs: RunStore
    private let accounts: AccountStore
    private let system: any SystemActions
    private let clock: any Clock<Duration>

    @ObservationIgnored var onStateChange: ((NotchState) -> Void)?
    @ObservationIgnored var onOpenSettings: ((SettingsPage?) -> Void)?

    @ObservationIgnored private var hoverTask: Task<Void, Never>?
    @ObservationIgnored private var waitingForPointerExit = false
    @ObservationIgnored private var pointer: NSPoint?
    @ObservationIgnored private var pointerLeft = false
    @ObservationIgnored private var buttonHeld = false

    init(
        list: PRListModel,
        actions: ActionsModel,
        peeks: PeekPresenter,
        liveCI: LiveCIModel,
        runs: RunStore,
        accounts: AccountStore,
        system: any SystemActions,
        geometry: NotchGeometry,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.list = list
        self.actions = actions
        self.peeks = peeks
        liveCIModel = liveCI
        self.runs = runs
        self.accounts = accounts
        self.system = system
        self.geometry = geometry
        self.clock = clock
        peeks.host = self
    }

    var layout: NotchLayout { NotchLayout(geometry: geometry, closedWings: liveCI?.wingWidth ?? 0) }

    var liveCI: LiveCI? { liveCIModel.current }

    var peekAlert: NotchAlert? { peeks.alert }

    // MARK: - Pointer

    func mouseMoved(to point: NSPoint, buttonHeld: Bool = false, leaving: Bool = false, opensOnHover: Bool = true) {
        pointer = point
        pointerLeft = leaving
        self.buttonHeld = buttonHeld
        let inside = !leaving && layout.hitRect(for: state).contains(point)

        if waitingForPointerExit {
            if !inside { waitingForPointerExit = false }
            return
        }

        switch state {
        case .peek:
            peeks.pointerMoved(over: inside)
        case .closed:
            guard inside, opensOnHover else { return cancelHover() }
            scheduleHover(after: .milliseconds(80)) { notch in
                if notch.isPointerOver(notch.state) { notch.open() }
            }
        case .open:
            if list.keyboardMode {
                if inside { list.keyboardMode = false }
                return
            }
            guard !inside, !buttonHeld, !holdsOpenForSetup else { return cancelHover() }
            scheduleHover(after: .milliseconds(200)) { notch in
                if !notch.isPointerOver(.open), !notch.buttonHeld { notch.close() }
            }
        }
    }

    func mouseDown(at point: NSPoint) {
        if state == .open, !holdsOpenForSetup, !layout.hitRect(for: .open).contains(point) { close() }
    }

    var holdsOpenForSetup: Bool {
        accounts.accounts.isEmpty
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
        !pointerLeft && (pointer.map(layout.hitRect(for: state).contains) ?? false)
    }

    private func cancelHover() {
        hoverTask?.cancel()
        hoverTask = nil
    }

    // MARK: - Transitions

    func open(viaKeyboard: Bool = false) {
        list.keyboardMode = viaKeyboard
        if viaKeyboard { list.selectFirstIfNeeded() }
        if viaKeyboard, area == .actions { actions.selectFirstIfNeeded() }
        withAnimation(Motion.open) {
            peeks.clearForOpen()
            state = .open
        }
    }

    func toggleFromKeyboard() {
        if state == .open { close() } else { open(viaKeyboard: true) }
    }

    func reopen() {
        if state == .open {
            list.keyboardMode = true
        } else {
            open(viaKeyboard: true)
        }
    }

    func close(pointerStaysOver: Bool = false) {
        cancelHover()
        peeks.stop()
        waitingForPointerExit = pointerStaysOver
        list.reset()
        actions.resetSelection()
        withAnimation(Motion.close) { state = .closed }
    }

    func show(_ area: PanelArea) {
        guard area != self.area else { return }
        if list.isSearching { list.stopSearch() }
        withAnimation(Motion.navigate) { self.area = area }
        if area == .actions, list.keyboardMode { actions.selectFirstIfNeeded() }
    }

    // MARK: - Alerts

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
            self?.peeks.preview(events)
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
        if area == .actions, !command.worksEverywhere { return performInActions(command) }
        switch command {
        case .quit: system.quit()
        case .settings: onOpenSettings?(nil)
        case .search: list.startSearch()
        case .close:
            if area == .actions, actions.back() { break }
            if list.isSearching { list.stopSearch() } else { close() }
        case .moveUp, .moveDown:
            list.keyboardMode = true
            list.moveSelection(by: command == .moveUp ? -1 : 1)
        case .switchTab: list.selectTab(by: 1)
        case .previousTab: list.selectTab(by: -1)
        case .selectTab(let number):
            return area == .actions ? actions.selectTab(number: number) : list.selectTab(number: number)
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

    private func performInActions(_ command: KeyCommand) -> Bool {
        if let run = actions.openedRun {
            guard command == .open else { return false }
            openInBrowser(run.url)
            return true
        }
        switch command {
        case .moveUp, .moveDown:
            list.keyboardMode = true
            return actions.moveSelection(by: command == .moveUp ? -1 : 1)
        case .switchTab: return actions.selectTab(by: 1)
        case .previousTab: return actions.selectTab(by: -1)
        case .open:
            guard let run = actions.selectedRun else { return false }
            actions.open(run)
            return true
        default: return false
        }
    }
}

// MARK: - PeekHost

extension NotchInteraction: PeekHost {
    func peekStarted() {
        state = .peek
    }

    func peekEnded() {
        state = .closed
    }
}
