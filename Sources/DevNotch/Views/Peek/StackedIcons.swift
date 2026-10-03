import SwiftUI

/// Overlapping icons that fan out one after another when several alerts arrive together.
struct StackedIcons: View {
    let alerts: [NotchAlert]
    @ViewState private var fanned = false

    var body: some View {
        HStack(spacing: -10) {
            ForEach(Array(alerts.enumerated()), id: \.element.id) { index, alert in
                ZStack {
                    Circle().fill(.black)
                    Circle().fill(alert.tint.opacity(0.22))
                    Image(systemName: alert.symbol)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(alert.tint)
                }
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(.black, lineWidth: 2))
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
