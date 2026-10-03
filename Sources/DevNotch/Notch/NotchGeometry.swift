import AppKit

struct NotchGeometry: Equatable {
    static let panelSize = CGSize(width: 820, height: 480)

    var screenFrame: NSRect
    var notchSize: CGSize
    var hasNotch: Bool

    var panelFrame: NSRect {
        NSRect(
            x: screenFrame.midX - Self.panelSize.width / 2,
            y: screenFrame.maxY - Self.panelSize.height,
            width: Self.panelSize.width,
            height: Self.panelSize.height
        )
    }

    @MainActor
    static func current() -> NotchGeometry {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = frame.width - left.width - right.width
            return NotchGeometry(
                screenFrame: frame,
                notchSize: CGSize(width: width, height: screen.safeAreaInsets.top),
                hasNotch: true
            )
        }
        // External displays have no notch: anchor a virtual one to the top center of the menu bar.
        let menuBarHeight = max(frame.maxY - screen.visibleFrame.maxY, 24)
        return NotchGeometry(screenFrame: frame, notchSize: CGSize(width: 180, height: menuBarHeight), hasNotch: false)
    }
}
