import SwiftUI

struct SearchTrigger: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.panel(.caption, .semibold))
                Text("Search")
                    .font(.panel(.body, .medium))
                Spacer(minLength: 8)
                Text("⌘F")
                    .font(.keycap)
                    .foregroundStyle(.textTertiary)
            }
            .foregroundStyle(hovering ? .textStrong : .textSecondary)
            .padding(.horizontal, 10)
            .frame(width: 128, height: 26)
            .background(Capsule().fill(hovering ? .surface : .surfaceSubtle))
            .overlay(Capsule().strokeBorder(.hairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
        .hint(String(localized: "Search by title, repo, #number, branch or author"), edge: .leading)
    }
}
