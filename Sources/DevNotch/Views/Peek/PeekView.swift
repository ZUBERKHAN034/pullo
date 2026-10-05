import SwiftUI

struct PeekView: View {
    let alert: NotchAlert
    let onTap: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        HStack(spacing: 11) {
            if alert.stack.isEmpty {
                ZStack {
                    Circle().fill(alert.tint.opacity(0.2))
                    Image(systemName: alert.symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(alert.tint)
                        .symbolEffect(.bounce, options: .speed(0.8), value: alert.id)
                }
                .frame(width: 30, height: 30)
            } else {
                StackedIcons(alerts: Array(alert.stack.prefix(3)))
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(alert.headline)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let account = alert.account {
                        Text(verbatim: "@\(account)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.white.opacity(0.1)))
                    }
                }
                Text(alert.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            // Tapping opens the PR, or the panel when several alerts are stacked.
            Image(systemName: alert.url == nil ? "chevron.down" : "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
                .opacity(hovering ? 1 : 0)
                .animation(Motion.hover, value: hovering)
        }
        .padding(.horizontal, 18)
        .frame(height: 54, alignment: .center)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onTap)
    }
}
