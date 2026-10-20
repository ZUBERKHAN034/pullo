import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let demo: DemoMode? = DemoMode.current
    private lazy var defaults = demo?.defaults ?? .standard
    private let tokens = TokenProvider(cli: GHCLI())
    private lazy var accounts = AccountStore(defaults: defaults, cli: GHCLI(), tokens: tokens)
    private lazy var settings = AppSettings(defaults: defaults)
    private lazy var tracker = ReadTracker(defaults: defaults)
    private lazy var store = PRStore(
        accounts: accounts,
        tracker: tracker,
        source: demo?.source ?? GitHubSource(tokens: tokens)
    )
    private lazy var model = NotchViewModel(
        store: store, accounts: accounts, settings: settings, tracker: tracker,
        geometry: NotchGeometry.notchedScreen.map { NotchGeometry(screen: $0) } ?? .placeholder
    )
    private lazy var updater = demo == nil ? Updater() : nil
    private lazy var settingsWindow = SettingsWindowController { [unowned self] navigation in
        SettingsForm(settings: settings, accounts: accounts, model: model, updater: updater, navigation: navigation)
    }
    private var panel: NotchPanel?
    private var hotKey: HotKey?
    private var monitors: [Any] = []
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NotchPanel(rootView: NotchRootView(model: model, store: store, accounts: accounts))
        self.panel = panel
        panel.setFrame(model.geometry.panelFrame, display: true)
        panel.orderFrontRegardless()

        model.$geometry
            .removeDuplicates()
            .sink { [weak panel] geometry in panel?.setFrame(geometry.panelFrame, display: true) }
            .store(in: &cancellables)
        model.$state
            .sink { [weak self] state in self?.stateChanged(to: state) }
            .store(in: &cancellables)

        store.onEvents = { [weak self] events in self?.model.enqueue(events: events) }
        model.onNeedsKeyFocus = { [weak panel] in panel?.makeKeyAndOrderFront(nil) }
        model.onOpenSettings = { [weak self] page in
            self?.model.close()
            self?.settingsWindow.show(page: page)
        }
        accounts.onAccountAdded = { [weak self] account in self?.model.accountConnected(account) }
        accounts.onAccountRemoved = { [weak self] account in
            self?.tracker.forget(account: account.login)
            self?.settings.mutedAccounts.remove(account.login)
        }

        if let demo {
            Task { await demo.play(model: model, store: store) }
            return
        }

        store.start()
        _ = updater
        if accounts.accounts.isEmpty { greetFirstLaunch() }

        hotKey = HotKey(.togglePanel) { [weak self] in
            MainActor.assumeIsolated { self?.toggleFromKeyboard() }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshAfterWake()
            }
        }
        installEventMonitors()
    }

    private func refreshAfterWake() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            await self?.store.refresh()
        }
    }

    private func stateChanged(to state: NotchState) {
        guard let panel else { return }
        updateMouseCapture()
        if state == .closed, panel.isKeyWindow {
            DispatchQueue.main.async {
                panel.orderOut(nil)
                panel.orderFrontRegardless()
            }
        }
    }

    private func toggleFromKeyboard() {
        model.toggleFromKeyboard()
        if model.state == .open { panel?.makeKeyAndOrderFront(nil) }
    }

    private func greetFirstLaunch() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.model.enqueue(NotchAlert(
                symbol: "hand.wave.fill",
                tint: .blue,
                headline: "Welcome to DevNotch",
                detail: "Hover here to connect GitHub"
            ))
        }
    }

    private func screensChanged() {
        guard let screen = NotchGeometry.notchedScreen else { return }
        let target = NotchGeometry(screen: screen)
        if target.screenFrame != model.geometry.screenFrame { model.close() }
        model.geometry = target
    }

    private func mouseMoved() {
        model.mouseMoved(to: NSEvent.mouseLocation)
        updateMouseCapture()
    }

    private func updateMouseCapture() {
        let state = model.state
        let over = model.layout.hitRect(for: state).contains(NSEvent.mouseLocation)
        let ignores = state == .closed || !over
        if panel?.ignoresMouseEvents != ignores { panel?.ignoresMouseEvents = ignores }
    }

    private func installEventMonitors() {
        let pointer: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: pointer.union(.leftMouseDown), handler: { [weak self] event in
            MainActor.assumeIsolated {
                if event.type == .leftMouseDown {
                    self?.model.mouseDown(at: NSEvent.mouseLocation)
                } else {
                    self?.mouseMoved()
                }
            }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: pointer, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        }) {
            monitors.append(local)
        }
        if let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.model.handleKey(event) == true }
            return handled ? nil : event
        }) {
            monitors.append(keys)
        }
    }
}
