import SwiftUI

/// The few keys worth showing; the rest are in each button's tooltip.
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
            Text(key)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.1)))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.tertiaryText)
        }
    }
}
