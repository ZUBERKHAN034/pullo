import SwiftUI

struct IconButton: View {
    @Environment(\.panelGlass) private var glass
    let symbol: String
    let help: String
    var spinning = false
    var active = false
    var floating = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.panel(.body, .semibold))
                .foregroundStyle(hovering || active ? Color.white : .textSecondary)
                .spinning(spinning, period: 0.8)
                .frame(width: 26, height: glass && floating ? 26 : 22)
                .background {
                    if !(glass && floating) {
                        Circle().fill(active ? .surfaceStrong : hovering ? .surface : Color.clear)
                    }
                }
                .panelGlass(floating, in: Circle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(help)
        .onHover { hovering = $0 }
        .hint(help)
    }
}
