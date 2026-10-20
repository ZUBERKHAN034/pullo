import AppKit
import SwiftUI

@MainActor
final class DemoStage {
    let model: DemoStageModel
    let captureRect: CGRect

    private let backdrop: NSWindow
    private let pointer: NSWindow

    init(screen: NSScreen, menuBarHeight: CGFloat) {
        let width = min(1280, screen.frame.width)
        let size = CGSize(width: width, height: (width * 9 / 16).rounded())
        captureRect = CGRect(x: ((screen.frame.width - size.width) / 2).rounded(), y: 0, width: size.width, height: size.height)
        model = DemoStageModel(cursor: CGPoint(x: size.width / 2, y: size.height * 0.8))

        let frame = NSRect(
            x: screen.frame.minX + captureRect.minX,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        backdrop = Self.window(frame: frame, level: NSWindow.Level.mainMenu.rawValue + 2,
                               content: StageView(model: model, menuBarHeight: menuBarHeight))
        pointer = Self.window(frame: frame, level: NSWindow.Level.mainMenu.rawValue + 4,
                              content: PointerView(model: model))
    }

    func show() {
        backdrop.orderFrontRegardless()
        pointer.orderFrontRegardless()
    }

    private static func window(frame: NSRect, level: Int, content: some View) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: level)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: content)
        return window
    }
}
