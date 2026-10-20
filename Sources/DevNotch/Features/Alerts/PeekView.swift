import SwiftUI

struct PeekView: View {
    let alert: NotchAlert
    let onTap: () -> Void
    @State private var hovering = false

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
                            .font(.panel(.headline, .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        accountChip
                    }
                    Text(alert.detail)
                        .font(.panel(.small))
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            } else {
                stackedLines
            }
            Spacer(minLength: 0)
            Image(systemName: alert.url == nil ? "chevron.down" : "arrow.up.right")
                .font(.panel(.small, .bold))
                .foregroundStyle(.textSecondary)
                .opacity(hovering ? 1 : 0)
                .animation(Motion.hover, value: hovering)
        }
        .padding(.horizontal, 18)
        .frame(height: 54, alignment: .center)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
    }

    private var stackedLines: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(alert.stack.prefix(2).enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 6) {
                    Text(item.headline)
                        .font(.panel(.label, .semibold))
                        .foregroundStyle(.white)
                        .layoutPriority(1)
                    if let reference = item.reference {
                        Text(reference)
                            .font(.panel(.small))
                            .foregroundStyle(.textSecondary)
                    }
                    if index == 0 { accountChip }
                }
                .lineLimit(1)
            }
            if let footnote {
                Text(footnote)
                    .font(.panel(.caption, .medium))
                    .foregroundStyle(.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private var footnote: String? {
        let more = alert.stack.count > 2 ? String(localized: "+\(alert.stack.count - 2) more") : nil
        let parts = [alert.note, more].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var accountChip: some View {
        if let account = alert.account {
            Chip(text: "@\(account)")
        }
    }
}
