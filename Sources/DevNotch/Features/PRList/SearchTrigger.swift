import SwiftUI

struct SearchTrigger: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10.5, weight: .semibold))
                Text("Filter")
                    .font(.system(size: 11.5, weight: .medium))
                Spacer(minLength: 8)
                Text("⌘F")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.tertiaryText)
            }
            .foregroundStyle(hovering ? Color.white.opacity(0.85) : Color.secondaryText)
            .padding(.horizontal, 10)
            .frame(width: 128, height: 26)
            .background(Capsule().fill(.white.opacity(hovering ? 0.1 : 0.06)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
        .hint("Filter by title, repo, #number, branch or author", edge: .leading)
    }
}
