import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    init(rootView: some View) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        contentView = hosting
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
