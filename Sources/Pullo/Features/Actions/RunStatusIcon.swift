import SwiftUI

struct RunStatusIcon: View {
    let run: WorkflowRun
    var size: CGFloat = 14

    var body: some View {
        Group {
            switch run.state {
            case .running:
                if let jobs = run.jobs, jobs.total > 0 {
                    ProgressRing(fraction: jobs.fraction, size: size, color: jobs.failed > 0 ? .red : .yellow)
                } else {
                    StatusIcon(status: .ciRunning, size: size)
                }
            case .queued: symbol("circle.dashed", .textTertiary)
            case .waiting: symbol("pause.circle.fill", .orange)
            case .passed: symbol("checkmark.circle.fill", .green)
            case .failed: symbol("xmark.circle.fill", .red)
            case .cancelled: symbol("stop.circle", .textTertiary)
            case .skipped: symbol("forward.circle", .textMuted)
            }
        }
        .frame(width: size, height: size)
    }

    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
    }
}
