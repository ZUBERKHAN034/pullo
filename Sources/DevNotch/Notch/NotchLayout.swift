import AppKit

struct NotchLayout {
    let geometry: NotchGeometry

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
            return NSRect(x: rect.minX - 10, y: rect.minY - 4, width: rect.width + 20, height: rect.height + 6)
        case .peek:
            return rect.insetBy(dx: 0, dy: -2)
        case .open:
            return rect.insetBy(dx: -16, dy: -16)
        }
    }
}
