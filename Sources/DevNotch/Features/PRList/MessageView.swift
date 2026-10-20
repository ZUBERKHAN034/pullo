import SwiftUI

struct MessageView: View {
    let symbol: String
    let title: String
    let detail: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.textTertiary)
            Text(title)
                .font(.panel(.headline, .semibold))
                .foregroundStyle(.textStrong)
            Text(detail)
                .font(.panel(.body))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if let retry {
                Button("Try again", action: retry)
                    .buttonStyle(.plain)
                    .font(.panel(.body, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.surfaceStrong))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }
}
