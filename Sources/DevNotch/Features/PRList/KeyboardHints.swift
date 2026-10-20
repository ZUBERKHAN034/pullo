import SwiftUI

struct KeyboardHints: View {
    let searching: Bool

    var body: some View {
        HStack(spacing: 12) {
            hint("↑↓", "navigate")
            hint("↩", "open")
            if searching {
                hint("esc", "clear search")
            } else {
                hint("⌘F", "search")
                hint("esc", "close")
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
