import SwiftUI

struct PillButton: View {
    let title: String
    let symbol: String?
    var prominent = false
    var loading = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading {
                    ProgressView().controlSize(.mini)
                } else if let symbol {
                    Image(systemName: symbol).font(.panel(.caption, .bold))
                }
                Text(title).font(.panel(.body, .semibold))
            }
            .foregroundStyle(prominent ? .black : .textStrong)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(prominent ? .white.opacity(hovering ? 1 : 0.9) : hovering ? .surfaceStrong : .surface)
            )
            .scaleEffect(hovering ? 1.03 : 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(loading)
        .onHover { hovering = $0 }
        .animation(Motion.pop, value: hovering)
    }
}
