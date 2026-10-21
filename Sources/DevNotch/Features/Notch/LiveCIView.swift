import SwiftUI

struct LiveCIView: View {
    let live: LiveCI
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: notchWidth)
            counter
                .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var leading: some View {
        HStack(spacing: 4) {
            indicator
            if live.showsNumberBeside {
                label(live.numberText)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.panel(.small, .semibold).monospacedDigit())
            .foregroundStyle(live.failing ? Color.red : .textStrong)
            .contentTransition(.numericText())
    }

    @ViewBuilder
    private var indicator: some View {
        switch live.finished {
        case .success: result("checkmark.circle.fill", .green)
        case .failure: result("xmark.circle.fill", .red)
        default: ProgressRing(fraction: live.checks?.fraction ?? 0, color: live.failing ? .red : .yellow)
        }
    }

    private func result(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(color)
            .transition(.scale.combined(with: .opacity))
    }

    private var counter: some View {
        HStack(spacing: 4) {
            if let text = live.trailingText {
                label(text)
            }
            if let others = live.othersText {
                Text(verbatim: others)
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.surface))
            }
        }
    }

    private var accessibilityText: String {
        let checks = live.checks.map { String(localized: "\($0.done) of \($0.total) checks done") } ?? ""
        let title = live.title
        switch live.finished {
        case .success: return String(localized: "Checks passed on \(title)")
        case .failure: return String(localized: "Checks failed on \(title)")
        default: return String(localized: "Checks running on \(title), \(checks)")
        }
    }
}
