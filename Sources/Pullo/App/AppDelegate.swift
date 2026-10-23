import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let app = AppDependencies(demo: DemoMode.current)
    private var panel: NotchPanelController?
    private lazy var settingsWindow = SettingsWindowController { [app] navigation in
        AnyView(app.inject(into: SettingsForm(updater: app.updater, navigation: navigation)))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NotchPanelController(app: app)
        self.panel = panel
        app.notch.onOpenSettings = { [weak self] page in
            self?.app.notch.close()
            self?.settingsWindow.show(page: page)
        }

        if let demo = app.demo {
            Task { await demo.play(model: app.notch, store: app.store) }
            return
        }

        app.store.start()
        app.runs.start()
        app.accounts.watchForGHLogins()
        if app.accounts.accounts.isEmpty { greetFirstLaunch() } else { app.system.requestFocusAccess() }
        panel.startListening()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAfterWake() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard app.demo == nil else { return true }
        panel?.reopen()
        return false
    }

    private func refreshAfterWake() {
        Task { [app] in
            try? await Task.sleep(for: .seconds(3))
            await app.store.refresh()
            await app.runs.refresh()
        }
    }

    private func greetFirstLaunch() {
        Task { [app] in
            try? await Task.sleep(for: .seconds(1))
            app.notch.enqueue(NotchAlert(
                symbol: "hand.wave.fill",
                tint: .blue,
                headline: String(localized: "Welcome to Pullo"),
                detail: app.settings.shortcut.shortcut.map {
                    String(localized: "Hover here or press \($0.symbols) to connect GitHub")
                } ?? String(localized: "Hover here to connect GitHub")
            ))
        }
    }
}
