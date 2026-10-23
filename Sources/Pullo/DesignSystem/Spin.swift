import SwiftUI

struct Spin: ViewModifier {
    let active: Bool
    var period: Double = 0.9
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: !active)) { context in
            let turn = active ? context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: period * 2) / period : 0
            if reduceMotion {
                content.opacity(0.55 + 0.45 * abs(cos(turn * .pi / 2)))
            } else {
                content.rotationEffect(.degrees(turn.truncatingRemainder(dividingBy: 1) * 360))
            }
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
