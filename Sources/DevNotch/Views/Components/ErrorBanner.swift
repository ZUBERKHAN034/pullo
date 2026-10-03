import SwiftUI

/// A tappable orange strip for a problem that has somewhere to go to fix it.
struct ErrorBanner: View {
    let message: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(message)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.orange.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}
