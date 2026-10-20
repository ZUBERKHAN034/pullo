import SwiftUI

struct IconButton: View {
    let symbol: String
    let help: String
    var spinning = false
    var active = false
    var hintEdge: HorizontalEdge = .leading
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.panel(.body, .semibold))
                .foregroundStyle(hovering || active ? Color.white : .textSecondary)
                .spinning(spinning, period: 0.8)
                .frame(width: 26, height: 22)
                .background(Circle().fill(active ? .surfaceStrong : hovering ? .surface : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(help)
        .onHover { hovering = $0 }
        .hint(help, edge: hintEdge)
    }
}
