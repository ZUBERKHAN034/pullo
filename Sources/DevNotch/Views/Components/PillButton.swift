import SwiftUI

struct PillButton: View {
    let title: String
    let symbol: String?
    var prominent = false
    var loading = false
    let action: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading {
                    ProgressView().controlSize(.mini)
                } else if let symbol {
                    Image(systemName: symbol).font(.system(size: 10.5, weight: .bold))
                }
                Text(title).font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(prominent ? .black : .white.opacity(0.9))
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(prominent ? .white.opacity(hovering ? 1 : 0.9) : .white.opacity(hovering ? 0.16 : 0.1))
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
