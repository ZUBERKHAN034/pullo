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

    /// Nil only for the moment no display is attached at all, e.g. mid-way through a display change.
    @MainActor
    static var notchedScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    static let placeholder = NotchGeometry(screenFrame: .zero, notchSize: CGSize(width: 180, height: 24), hasNotch: false)
}

// In an extension so the memberwise initializer stays available.
@MainActor
extension NotchGeometry {
    init(screen: NSScreen) {
        let frame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = frame.width - left.width - right.width
            self.init(
                screenFrame: frame,
                notchSize: CGSize(width: width, height: screen.safeAreaInsets.top),
                hasNotch: true
            )
            return
        }
        // External displays have no notch: anchor a virtual one to the top center of the menu bar.
        let menuBarHeight = max(frame.maxY - screen.visibleFrame.maxY, 24)
        self.init(screenFrame: frame, notchSize: CGSize(width: 180, height: menuBarHeight), hasNotch: false)
    }
}
