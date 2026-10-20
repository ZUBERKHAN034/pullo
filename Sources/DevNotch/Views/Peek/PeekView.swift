import SwiftUI

struct PeekView: View {
    let alert: NotchAlert
    let onTap: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        HStack(spacing: 11) {
            if alert.stack.isEmpty {
                AlertIcon(alert: alert)
            } else {
                StackedIcons(alerts: Array(alert.stack.prefix(3)))
            }
            if alert.stack.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(alert.headline)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        accountChip
                    }
                    Text(alert.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }
            } else {
                stackedLines
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

    /// The two most important events, one per line, rather than one sentence cut off midway.
    private var stackedLines: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(alert.stack.prefix(2).enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 6) {
                    Text(item.headline)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    if let reference = item.reference {
                        Text(reference)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondaryText)
                    }
                    if index == 0 { accountChip }
                }
                .lineLimit(1)
            }
            if alert.stack.count > 2 {
                Text("+\(alert.stack.count - 2) more")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.tertiaryText)
            }
        }
    }

    @ViewBuilder
    private var accountChip: some View {
        if let account = alert.account {
            Text(verbatim: "@\(account)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(.white.opacity(0.1)))
        }
    }
}
