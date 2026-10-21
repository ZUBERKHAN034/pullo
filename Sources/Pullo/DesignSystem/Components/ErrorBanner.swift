import SwiftUI

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
            .font(.panel(.small, .medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.orange.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}
