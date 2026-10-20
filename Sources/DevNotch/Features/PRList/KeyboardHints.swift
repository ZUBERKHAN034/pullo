import SwiftUI

struct KeyboardHints: View {
    let searching: Bool

    var body: some View {
        HStack(spacing: 12) {
            hint("↑↓", String(localized: "navigate"))
            hint("↩", String(localized: "open"))
            if searching {
                hint("esc", String(localized: "clear search"))
            } else {
                hint("⌘F", String(localized: "search"))
                hint("esc", String(localized: "close"))
            }
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            KeyCap(key: key)
            Text(label)
                .font(.panel(.micro, .medium))
                .foregroundStyle(.textTertiary)
        }
    }
}
