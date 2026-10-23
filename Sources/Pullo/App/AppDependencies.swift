import AppKit
import SwiftUI

@MainActor
final class AppDependencies {
    let demo: DemoMode?
    let accounts: AccountStore
    let settings: AppSettings
    let tracker: ReadTracker
    let store: PRStore
    let runs: RunStore
    let toasts: ToastCenter
    let list: PRListModel
    let actions: ActionsModel
    let notch: NotchInteraction
    let updater: Updater?
    let system: any SystemActions
    let activity = ActivityMonitor()

    convenience init(demo: DemoMode?) {
        let cli = GHCLI()
        let tokens = TokenProvider(cli: cli)
        let prSource: any PRSource = demo?.source ?? GitHubSource(tokens: tokens)
        let runSource: any RunSource = demo == nil ? GitHubRunSource(tokens: tokens) : NoRuns()
        self.init(
            defaults: demo?.defaults ?? .standard,
            cli: cli,
            tokens: tokens,
            prSource: prSource,
            runSource: runSource,
            system: LiveSystemActions(),
            updater: demo == nil ? Updater() : nil,
            demo: demo
        )
    }

    init(
        defaults: UserDefaults,
        cli: any GitHubCLI,
        tokens: TokenProvider,
        session: URLSession = .shared,
        prSource: any PRSource,
        runSource: any RunSource,
        system: any SystemActions,
        geometry: NotchGeometry? = nil,
        clock: any Clock<Duration> = ContinuousClock(),
        now: @escaping () -> Date = Date.init,
        updater: Updater? = nil,
        demo: DemoMode? = nil
    ) {
        self.demo = demo
        self.system = system
        self.updater = updater
        accounts = AccountStore(defaults: defaults, cli: cli, tokens: tokens, session: session, clock: clock)
        settings = AppSettings(defaults: defaults)
        tracker = ReadTracker(defaults: defaults)
        store = PRStore(accounts: accounts, tracker: tracker, source: prSource, clock: clock, now: now)
        runs = RunStore(accounts: accounts, prs: store, source: runSource, clock: clock, now: now)
        toasts = ToastCenter(clock: clock)
        list = PRListModel(store: store, accounts: accounts, tracker: tracker, system: system, toasts: toasts)
        actions = ActionsModel(store: runs, accounts: accounts, toasts: toasts)
        notch = NotchInteraction(
            list: list,
            actions: actions,
            runs: runs,
            accounts: accounts,
            settings: settings,
            system: system,
            geometry: geometry ?? settings.display.screen().map { NotchGeometry(screen: $0) } ?? .placeholder,
            clock: clock
        )
        connect()
    }

    func inject(into view: some View) -> some View {
        view
            .environment(notch)
            .environment(list)
            .environment(store)
            .environment(accounts)
            .environment(tracker)
            .environment(settings)
            .environment(actions)
            .environment(toasts)
            .environment(\.system, system)
    }

    func startPolling() {
        activity.watch([store.poller, runs.poller])
        activity.start()
        store.start()
        runs.start()
    }

    private func connect() {
        runs.setPanelOpen(notch.state == .open)
        store.onEvents = { [weak self] events in self?.notch.enqueue(events: events) }
        runs.onRunsFinished = { [weak self] finished in self?.notch.runsFinished(finished) }
        accounts.onAccountAdded = { [weak self] account in
            guard let self else { return }
            notch.accountConnected(account)
            system.requestFocusAccess()
            Task {
                await self.store.refresh()
                await self.runs.refresh()
            }
        }
        accounts.onTabsChanged = { [weak self] in
            guard let self else { return }
            Task { await self.store.refresh() }
        }
        accounts.onAccountRemoved = { [weak self] account in
            guard let self else { return }
            tracker.forget(account: account.login)
            settings.mutedAccounts.remove(account.login)
            Task {
                await self.store.refresh()
                await self.runs.refresh()
            }
        }
    }
}
