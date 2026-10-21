import SwiftUI

struct StatusIcon: View {
    let status: PRStatus
    var size: CGFloat = 14

    var body: some View {
        Group {
            switch status {
            case .conflict: symbol("exclamationmark.triangle.fill", .orange)
            case .ciFailed: symbol("xmark.circle.fill", .red)
            case .changesRequested: symbol("arrow.uturn.backward.circle.fill", .red)
            case .ciRunning: running
            case .readyToMerge: symbol("checkmark.circle.fill", Color(red: 0.49, green: 0.53, blue: 1))
            case .draft: symbol("circle.dashed", .textTertiary)
            case .ciPassed: symbol("checkmark.circle.fill", .green)
            case .noChecks: symbol("circle", .textMuted)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(status.explanation)
    }

    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
    }

    private var running: some View {
        let line = max(1.5, size / 8)
        return ZStack {
            Circle().stroke(Color.yellow.opacity(0.25), lineWidth: line)
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .spinning()
        }
        .padding(line / 2 + 1)
    }
}
