import AppKit
import SwiftUI

/// A regular macOS settings window, opened from the gear in the panel.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let content: () -> SettingsForm

    init(content: @escaping () -> SettingsForm) {
        self.content = content
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "DevNotch Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: content())
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
