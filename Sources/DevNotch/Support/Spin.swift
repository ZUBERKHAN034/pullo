import SwiftUI

/// Continuous rotation driven by the clock rather than a repeating animation.
/// A `repeatForever` animation leaks into whatever else animates nearby (rows sliding in, the panel opening)
/// and makes the spinner jump; reading the time each frame can't.
struct Spin: ViewModifier {
    let active: Bool
    var period: Double = 0.9

    func body(content: Content) -> some View {
        if active {
            TimelineView(.animation) { context in
                let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                content.rotationEffect(.degrees(turn * 360))
            }
        } else {
            content
        }
    }
}

extension View {
    func spinning(_ active: Bool = true, period: Double = 0.9) -> some View {
        modifier(Spin(active: active, period: period))
    }
}
