import AppKit
import SwiftUI

@MainActor
final class AppDependencies {
    let demo: DemoMode?
    let accounts: AccountStore
    let settings: AppSettings
    let tracker: ReadTracker
    let store: PRStore
    let list: PRListModel
    let notch: NotchInteraction
    let runs: RunStore
    let actions: ActionsModel
    let updater: Updater?
    let system: any SystemActions = LiveSystemActions()
    let activity = ActivityMonitor()

    init(demo: DemoMode?) {
        self.demo = demo
        let defaults = demo?.defaults ?? .standard
        let cli = GHCLI()
        let tokens = TokenProvider(cli: cli)
        accounts = AccountStore(defaults: defaults, cli: cli, tokens: tokens)
        settings = AppSettings(defaults: defaults)
        tracker = ReadTracker(defaults: defaults)
        store = PRStore(accounts: accounts, tracker: tracker, source: demo?.source ?? GitHubSource(tokens: tokens))
        list = PRListModel(store: store, accounts: accounts, tracker: tracker, system: system)
        runs = RunStore(accounts: accounts, prs: store, source: demo == nil ? GitHubRunSource(tokens: tokens) : NoRuns())
        actions = ActionsModel(store: runs, list: list, accounts: accounts)
        notch = NotchInteraction(
            list: list,
            runs: runs,
            accounts: accounts,
            settings: settings,
            system: system,
            geometry: NotchGeometry.notchedScreen.map { NotchGeometry(screen: $0) } ?? .placeholder
        )
        updater = demo == nil ? Updater() : nil
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
        notch.actions = actions
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
