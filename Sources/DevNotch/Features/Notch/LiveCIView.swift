import SwiftUI

struct LiveCIView: View {
    let live: LiveCI
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            indicator
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: notchWidth)
            counter
                .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var indicator: some View {
        switch live.finished {
        case .success: result("checkmark.circle.fill", .green)
        case .failure: result("xmark.circle.fill", .red)
        default: CIProgressRing(fraction: live.checks?.fraction ?? 0)
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
            if let checks = live.checks {
                Text(verbatim: "\(checks.done)/\(checks.total)")
                    .font(.panel(.small, .semibold).monospacedDigit())
                    .foregroundStyle(.textStrong)
                    .contentTransition(.numericText())
            }
            if live.othersRunning > 0 {
                Text(verbatim: "+\(live.othersRunning)")
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
        let title = live.pr.title
        switch live.finished {
        case .success: return String(localized: "Checks passed on \(title)")
        case .failure: return String(localized: "Checks failed on \(title)")
        default: return String(localized: "Checks running on \(title), \(checks)")
        }
    }
}

private struct CIProgressRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.yellow.opacity(0.25), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(fraction, 0.04))
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.reveal, value: fraction)
        }
        .frame(width: 14, height: 14)
    }
}
