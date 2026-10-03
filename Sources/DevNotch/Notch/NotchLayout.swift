import AppKit

/// Sizes and hit areas of the notch in each state, derived from the screen's real notch.
struct NotchLayout {
    let geometry: NotchGeometry

    /// Content size, not counting the flares the shape adds at the top corners.
    func size(for state: NotchState) -> CGSize {
        let notch = geometry.notchSize
        switch state {
        case .closed:
            return notch
        case .peek:
            return CGSize(width: max(notch.width + 200, 400), height: notch.height + 54)
        case .open:
            return CGSize(width: max(notch.width + 400, 620), height: notch.height + 330)
        }
    }

    func radii(for state: NotchState) -> (top: CGFloat, bottom: CGFloat) {
        switch state {
        case .closed: (6, 10)
        case .peek: (9, 20)
        case .open: (12, 28)
        }
    }

    /// Where the pointer counts as "over the notch", in screen coordinates.
    func hitRect(for state: NotchState) -> NSRect {
        let size = size(for: state)
        let width = size.width + radii(for: state).top * 2
        let rect = NSRect(
            x: geometry.screenFrame.midX - width / 2,
            y: geometry.screenFrame.maxY - size.height,
            width: width,
            height: size.height
        )
        switch state {
        case .closed:
            // A little wider and taller than the notch, so it's easy to hit from the menu bar.
            return NSRect(x: rect.minX - 10, y: rect.minY - 4, width: rect.width + 20, height: rect.height + 6)
        case .peek:
            return rect.insetBy(dx: 0, dy: -2)
        case .open:
            // Some slack, so brushing past the edge doesn't close the panel.
            return rect.insetBy(dx: -16, dy: -16)
        }
    }
}
