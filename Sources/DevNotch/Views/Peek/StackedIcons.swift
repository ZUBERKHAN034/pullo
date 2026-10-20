import SwiftUI

/// Overlapping icons that fan out one after another when several alerts arrive together.
struct StackedIcons: View {
    let alerts: [NotchAlert]
    @State private var fanned = false

    var body: some View {
        HStack(spacing: -10) {
            ForEach(Array(alerts.enumerated()), id: \.element.id) { index, alert in
                AlertIcon(alert: alert, size: 28)
                    .background(Circle().fill(.black).padding(-2))
                    .zIndex(Double(alerts.count - index))
                    .offset(x: fanned ? 0 : CGFloat(-index) * 18)
                    .scaleEffect(fanned ? 1 : 0.7)
                    .opacity(fanned ? 1 : 0)
                    .animation(Motion.pop.delay(0.1 + Double(index) * 0.09), value: fanned)
            }
        }
        .onAppear { fanned = true }
    }
}
