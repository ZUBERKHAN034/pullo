import AppKit
import SwiftUI

enum Motion {
    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    static var open: Animation { reduced ? fade : .spring(response: 0.42, dampingFraction: 0.78) }
    static var close: Animation { reduced ? fade : .spring(response: 0.36, dampingFraction: 0.92) }
    static var peek: Animation { reduced ? fade : .spring(response: 0.5, dampingFraction: 0.7) }
    static var navigate: Animation { reduced ? fade : .spring(response: 0.33, dampingFraction: 0.84) }
    static var reveal: Animation { reduced ? fade : .spring(response: 0.42, dampingFraction: 0.86) }
    static var pop: Animation { reduced ? fade : .spring(response: 0.3, dampingFraction: 0.7) }
    static let hover = Animation.easeOut(duration: 0.14)
    static let fade = Animation.easeOut(duration: 0.2)
}

extension AnyTransition {
    static func fadeSlide(from edge: Edge) -> AnyTransition {
        Motion.reduced ? .opacity : .opacity.combined(with: .move(edge: edge))
    }
}
