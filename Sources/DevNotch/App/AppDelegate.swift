import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let demo = DemoMode.current
    private lazy var defaults = demo == nil ? UserDefaults.standard : DemoData.freshDefaults()
    private lazy var demoSource = DemoSource()
    private lazy var accounts = AccountStore(defaults: defaults)
    private lazy var settings = AppSettings(defaults: defaults)
    private lazy var tracker = ReadTracker(defaults: defaults)
    private lazy var store = PRStore(
        accounts: accounts,
        tracker: tracker,
        source: demo == nil ? GitHubSource(accounts: accounts) : demoSource
    )
    private lazy var model = NotchViewModel(
        store: store, accounts: accounts, settings: settings, tracker: tracker,
        geometry: NotchGeometry(screen: NotchGeometry.notchedScreen)
    )
    private lazy var settingsWindow = SettingsWindowController { [unowned self] in
        SettingsForm(settings: settings, accounts: accounts, model: model)
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
        model.onOpenSettings = { [weak self] in
            self?.model.close()
            self?.settingsWindow.show()
        }
        accounts.onAccountAdded = { [weak self] account in self?.model.accountConnected(account) }

        if let demo {
            // The tour drives everything itself; a stray real mouse move or shortcut shouldn't interfere.
            Task { await demo.play(model: model, store: store, source: demoSource) }
            return
        }

        store.start()
        if accounts.accounts.isEmpty { greetFirstLaunch() }

        hotKey = HotKey(keyCode: kVK_ANSI_P, modifiers: cmdKey | optionKey) { [weak self] in
            MainActor.assumeIsolated { self?.toggleFromKeyboard() }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
        // The network takes a moment to come back after sleep; refresh once it has, not a minute later.
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
        // Clicks fall through to the menu bar unless the notch is showing something.
        panel.ignoresMouseEvents = state == .closed
        // Clicking inside makes the panel key; hand typing back to the app you were in once it closes.
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

    /// With no account the closed notch shows nothing, so point at it once.
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

    /// A display was plugged in, removed or rearranged, or the lid opened or closed.
    private func screensChanged() {
        let target = NotchGeometry(screen: NotchGeometry.notchedScreen)
        if target.screenFrame != model.geometry.screenFrame { model.close() }
        model.geometry = target
    }

    private func installEventMonitors() {
        let pointer: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: pointer.union(.leftMouseDown), handler: { [weak self] event in
            MainActor.assumeIsolated {
                if event.type == .leftMouseDown {
                    self?.model.mouseDown(at: NSEvent.mouseLocation)
                } else {
                    self?.model.mouseMoved(to: NSEvent.mouseLocation)
                }
            }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: pointer, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.model.mouseMoved(to: NSEvent.mouseLocation) }
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
