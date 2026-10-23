import AppKit

struct NotchGeometry: Equatable {
    static let panelSize = CGSize(width: 820, height: 480)
    static let pillWidth: CGFloat = 120

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
    static var notchedScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    static let placeholder = NotchGeometry(screenFrame: .zero, notchSize: CGSize(width: pillWidth, height: 24), hasNotch: false)
}

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
        let menuBarHeight = max(frame.maxY - screen.visibleFrame.maxY, 24)
        self.init(screenFrame: frame, notchSize: CGSize(width: Self.pillWidth, height: menuBarHeight), hasNotch: false)
    }
}
