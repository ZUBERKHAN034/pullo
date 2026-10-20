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
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(hovering || active ? 0.95 : 0.55))
                .spinning(spinning, period: 0.8)
                .frame(width: 26, height: 22)
                .background(Circle().fill(.white.opacity(active ? 0.14 : hovering ? 0.1 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .hint(help, edge: hintEdge)
    }
}
