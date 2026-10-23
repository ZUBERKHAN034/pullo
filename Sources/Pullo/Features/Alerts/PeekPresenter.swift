import AppKit
import Observation
import SwiftUI

@MainActor
protocol PeekHost: AnyObject {
    var state: NotchState { get }
    var geometry: NotchGeometry { get }
    func peekStarted()
    func peekEnded()
}

@MainActor
@Observable
final class PeekPresenter {
    static let finishedCITime: Duration = .seconds(2)

    private(set) var alert: NotchAlert?
    private(set) var finishedCI: LiveCI?

    @ObservationIgnored weak var host: (any PeekHost)?

    private let accounts: AccountStore
    private let settings: AppSettings
    private let system: any SystemActions
    private let clock: any Clock<Duration>

    @ObservationIgnored private var queue = AlertQueue()
    @ObservationIgnored private var dismissTask: Task<Void, Never>?
    @ObservationIgnored private var isHeldByPointer = false
    @ObservationIgnored private var missed: [NotchAlert] = []
    @ObservationIgnored private var missedReason = HoldReason.focus
    @ObservationIgnored private var holdWatch: Task<Void, Never>?
    @ObservationIgnored private var finishedCITask: Task<Void, Never>?

    init(accounts: AccountStore, settings: AppSettings, system: any SystemActions, clock: any Clock<Duration> = ContinuousClock()) {
        self.accounts = accounts
        self.settings = settings
        self.system = system
        self.clock = clock
    }

    private var state: NotchState { host?.state ?? .closed }

    // MARK: - Alerts

    func enqueue(_ alerts: [NotchAlert]) {
        guard state != .open, !alerts.isEmpty else { return }
        queue.append(alerts)
        if state == .closed { showNext() }
    }

    func enqueue(_ alert: NotchAlert) {
        enqueue([alert])
    }

    func enqueue(events: [PREvent]) {
        let shown = events.filter(settings.allows)
        let alerts = shown.map { $0.alert(showingAccount: accounts.hasMultipleAccounts) }
        guard let finished = shown.first(where: { $0.kind == .ciFailed }) ?? shown.first(where: { $0.kind == .ciPassed }),
              canFlashFinishedCI(of: finished.pr.account)
        else { return enqueue(alerts) }
        flash(LiveCI(pr: finished.pr, finished: finished.pr.ci), then: alerts)
    }

    func runsFinished(_ finished: [WorkflowRun]) {
        let shown = finished.filter { !settings.mutedAccounts.contains($0.account) }
        guard let run = shown.first(where: { $0.state == .failed }) ?? shown.first(where: { $0.state == .passed }),
              canFlashFinishedCI(of: run.account)
        else { return }
        flash(LiveCI(run: run, finished: run.state == .failed ? .failure : .success), then: [])
    }

    func accountConnected(_ account: Account) {
        enqueue(NotchAlert(
            symbol: "person.crop.circle.badge.checkmark",
            tint: .green,
            headline: String(localized: "Account connected"),
            detail: String(localized: "@\(account.login) · loading your PRs")
        ))
    }

    func preview(_ events: [PREvent]) {
        guard state == .closed else { return }
        queue.append(events.map { $0.alert(showingAccount: accounts.hasMultipleAccounts) })
        showNext(evenInFocus: true)
    }

    // MARK: - Notch changes

    func pointerMoved(over inside: Bool) {
        if inside {
            guard !isHeldByPointer else { return }
            isHeldByPointer = true
            dismissTask?.cancel()
        } else if isHeldByPointer {
            isHeldByPointer = false
            dismiss(after: .seconds(1.5))
        }
    }

    func clearForOpen() {
        stop()
        queue.removeAll()
        forgetMissedAlerts()
        alert = nil
    }

    func stop() {
        dismissTask?.cancel()
        isHeldByPointer = false
    }

    // MARK: - Finished CI

    private func canFlashFinishedCI(of account: String) -> Bool {
        state == .closed && finishedCITask == nil && settings.showsLiveCI && !settings.mutedAccounts.contains(account)
    }

    private func flash(_ live: LiveCI, then alerts: [NotchAlert]) {
        finishedCI = live
        let clock = clock
        finishedCITask = Task { [weak self] in
            try? await clock.sleep(for: Self.finishedCITime)
            guard let self else { return }
            finishedCI = nil
            finishedCITask = nil
            enqueue(alerts)
        }
    }

    // MARK: - Showing

    private func showNext(evenInFocus: Bool = false) {
        guard state == .closed, let next = queue.next() else { return }
        if !evenInFocus, let reason = holdReason {
            hold(next, because: reason)
            return
        }
        withAnimation(Motion.peek) {
            alert = next
            host?.peekStarted()
        }
        if settings.haptics { system.tapTrackpad() }
        if let sound = settings.sound(for: next.category) { system.play(sound: sound) }
        dismiss(after: AlertQueue.displayTime(for: next))
    }

    private func dismiss(after delay: Duration) {
        dismissTask?.cancel()
        let clock = clock
        dismissTask = Task { [weak self] in
            try? await clock.sleep(for: delay)
            guard let self, !Task.isCancelled, state == .peek else { return }
            withAnimation(Motion.close) { self.host?.peekEnded() }
            try? await clock.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            showNext()
        }
    }

    // MARK: - Focus and full screen

    private var holdReason: HoldReason? {
        if system.isInFocus { return .focus }
        if settings.holdsAlertsInFullScreen, let screen = host?.geometry.screenFrame, system.hasFullScreenApp(on: screen) {
            return .fullScreen
        }
        return nil
    }

    private func hold(_ alert: NotchAlert, because reason: HoldReason) {
        if missed.isEmpty { missedReason = reason }
        missed += alert.stack.isEmpty ? [alert] : alert.stack
        guard holdWatch == nil else { return }
        let clock = clock
        holdWatch = Task { [weak self] in
            while !Task.isCancelled {
                try? await clock.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                if holdReason == nil {
                    showMissedAlerts()
                    return
                }
            }
        }
    }

    private func showMissedAlerts() {
        holdWatch = nil
        guard !missed.isEmpty else { return }
        queue.append([NotchAlert.summary(of: missed, note: missedReason.note)])
        missed.removeAll()
        if state == .closed { showNext() }
    }

    private func forgetMissedAlerts() {
        holdWatch?.cancel()
        holdWatch = nil
        missed.removeAll()
    }
}

enum HoldReason {
    case focus, fullScreen

    var note: String {
        switch self {
        case .focus: String(localized: "While you were in Focus")
        case .fullScreen: String(localized: "While an app was full screen")
        }
    }
}
