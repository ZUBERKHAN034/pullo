import AppKit
import SwiftUI

/// A regular macOS settings window, opened from the gear in the panel.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let navigation = SettingsNavigation()
    private let content: (SettingsNavigation) -> SettingsForm

    init(content: @escaping (SettingsNavigation) -> SettingsForm) {
        self.content = content
    }

    /// Nil keeps the page it was left on.
    func show(page: SettingsPage? = nil) {
        if let page { navigation.page = page }
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "DevNotch Settings"
            // The sidebar runs up under the title bar, as in System Settings.
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: content(navigation))
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
