import SwiftUI

struct Spin: ViewModifier {
    let active: Bool
    var period: Double = 0.9
    @State private var start = Date()

    func body(content: Content) -> some View {
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
