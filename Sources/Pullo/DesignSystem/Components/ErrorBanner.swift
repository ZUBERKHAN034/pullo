import SwiftUI

struct ErrorBanner: View {
    let problem: RefreshProblem
    let updated: Date?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: problem.symbol)
                Text(message)
                    .lineLimit(1)
                Spacer()
                Image(systemName: problem.opensAccounts ? "chevron.right" : "arrow.clockwise")
            }
            .font(.panel(.small, .medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.orange.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .hint(problem.detail)
    }

    private var message: String {
        guard let updated else { return problem.title }
        return String(localized: "\(problem.title) · updated \(updated.shortAge) ago")
    }
}
