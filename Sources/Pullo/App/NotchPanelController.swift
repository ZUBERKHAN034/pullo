import AppKit
import Observation

@MainActor
final class NotchPanelController {
    private let app: AppDependencies
    private let panel: NotchPanel
    private var notch: NotchInteraction { app.notch }
    private var hotKey: HotKey?
    private var registeredShortcut: ShortcutChoice?
    private var monitors: [Any] = []
    private var pointerMonitor: Any?
    private var tracker: PointerTracker?

    init(app: AppDependencies) {
        self.app = app
        panel = NotchPanel(rootView: app.inject(into: NotchRootView()))
        panel.setFrame(app.notch.geometry.panelFrame, display: true)
        panel.orderFrontRegardless()

        notch.onStateChange = { [weak self] state in self?.stateChanged(to: state) }
        app.list.onNeedsKeyFocus = { [weak panel] in panel?.makeKeyAndOrderFront(nil) }
    }

    func startListening() {
        registerShortcut()
        observeSettings()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
        installEventMonitors()
        updatePointerMonitor()
    }

    func reopen() {
        notch.reopen()
        panel.makeKeyAndOrderFront(nil)
    }

    private func stateChanged(to state: NotchState) {
        if state == .open, !panel.isKeyWindow, NSEvent.pressedMouseButtons == 0 {
            panel.makeKeyAndOrderFront(nil)
        }
        if state == .closed, panel.isKeyWindow {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                MainActor.assumeIsolated { self?.giveUpKeyFocus() }
            }
        }
    }

    private func giveUpKeyFocus() {
        guard notch.state == .closed, panel.isKeyWindow else { return }
        panel.orderOut(nil)
        panel.orderFrontRegardless()
    }

    private func toggleFromKeyboard() {
        notch.toggleFromKeyboard()
        if notch.state == .open { panel.makeKeyAndOrderFront(nil) }
    }

    private func registerShortcut() {
        let choice = app.settings.shortcut
        guard choice != registeredShortcut else { return }
        hotKey = nil
        registeredShortcut = choice
        guard let shortcut = choice.shortcut else {
            app.settings.shortcutUnavailable = false
            return
        }
        hotKey = HotKey(shortcut) { [weak self] in
            MainActor.assumeIsolated { self?.toggleFromKeyboard() }
        }
        app.settings.shortcutUnavailable = hotKey == nil
    }

    private func observeSettings() {
        withObservationTracking {
            _ = app.settings.shortcut
            _ = app.settings.display
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.registerShortcut()
                    self?.updatePointerMonitor()
                    self?.screensChanged()
                    self?.observeSettings()
                }
            }
        }
    }

    private func followPointer(to point: NSPoint) {
        guard app.settings.display == .pointer, notch.state == .closed,
              !notch.geometry.screenFrame.insetBy(dx: 0, dy: -1).contains(point)
        else { return }
        screensChanged()
    }

    private func screensChanged() {
        guard let screen = app.settings.display.screen() else { return }
        let target = NotchGeometry(screen: screen)
        guard target != notch.geometry else { return }
        if target.screenFrame != notch.geometry.screenFrame { notch.close() }
        notch.geometry = target
        panel.setFrame(target.panelFrame, display: true)
    }

    private func pointerChanged(leaving: Bool = false) {
        notch.mouseMoved(
            to: NSEvent.mouseLocation,
            buttonHeld: NSEvent.pressedMouseButtons & 1 != 0,
            leaving: leaving,
            opensOnHover: app.settings.opensOnHover
        )
    }

    private func updatePointerMonitor() {
        let follows = app.settings.display == .pointer
        guard follows != (pointerMonitor != nil) else { return }
        if let pointerMonitor {
            NSEvent.removeMonitor(pointerMonitor)
            self.pointerMonitor = nil
        } else {
            pointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                MainActor.assumeIsolated { self?.followPointer(to: NSEvent.mouseLocation) }
            }
        }
    }

    private func installEventMonitors() {
        if let view = panel.contentView {
            tracker = PointerTracker(view: view) { [weak self] leaving in self?.pointerChanged(leaving: leaving) }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp], handler: { [weak self] event in
            MainActor.assumeIsolated {
                if event.type == .leftMouseDown {
                    self?.notch.mouseDown(at: NSEvent.mouseLocation)
                } else {
                    self?.pointerChanged()
                }
            }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.pointerChanged() }
            return event
        }) {
            monitors.append(local)
        }
        if let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.notch.handleKey(event) == true }
            return handled ? nil : event
        }) {
            monitors.append(keys)
        }
    }
}
