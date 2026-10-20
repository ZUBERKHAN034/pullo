import SwiftUI

/// Continuous rotation driven by the clock rather than a repeating animation.
/// A `repeatForever` animation leaks into whatever else animates nearby (rows sliding in, the panel opening)
/// and makes the spinner jump; reading the time each frame can't.
struct Spin: ViewModifier {
    let active: Bool
    var period: Double = 0.9
    /// Turns count from when it started, so it begins upright instead of at whatever angle the clock is on.
    @State private var start = Date()

    func body(content: Content) -> some View {
        // One view whether it spins or not, so starting and stopping doesn't swap it out mid-frame.
        TimelineView(.animation(paused: !active)) { context in
            let elapsed = active ? context.date.timeIntervalSince(start) : 0
            content.rotationEffect(.degrees(elapsed.truncatingRemainder(dividingBy: period) / period * 360))
        }
        .onChange(of: active) { _, spinning in
            if spinning { start = Date() }
        }
    }
}

extension View {
    func spinning(_ active: Bool = true, period: Double = 0.9) -> some View {
        modifier(Spin(active: active, period: period))
    }
}
