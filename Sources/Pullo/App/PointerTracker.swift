import AppKit

final class PointerTracker: NSResponder {
    private let onChange: @MainActor (_ leaving: Bool) -> Void

    init(view: NSView, onChange: @escaping @MainActor (_ leaving: Bool) -> Void) {
        self.onChange = onChange
        super.init()
        view.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func mouseEntered(with event: NSEvent) {
        onChange(false)
    }

    override func mouseMoved(with event: NSEvent) {
        onChange(false)
    }

    override func mouseExited(with event: NSEvent) {
        onChange(true)
    }
}
