import SwiftUI

struct RunRow: View {
    @Environment(ActionsModel.self) private var actions
    let run: WorkflowRun

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            RunStatusIcon(run: run)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(run.workflow)
                        .font(.panel(.title, .semibold))
                        .foregroundStyle(.textStrong)
                    Text(verbatim: run.pullRequest.map { "\(run.repoName) #\($0)" } ?? run.repoName)
                        .font(.panel(.title))
                        .foregroundStyle(.textTertiary)
                }
                .lineLimit(1)
                HStack(spacing: 5) {
                    AccountMark(login: run.account)
                    Text(details.joined(separator: " · "))
                        .font(.panel(.small))
                        .foregroundStyle(detailColor)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(time)
                .font(.panel(.small, .medium).monospacedDigit())
                .foregroundStyle(.textSecondary)
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(hovering ? Color.surfaceSubtle : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
        .onTapGesture { actions.open(run) }
        .onDrag { run.dragItem }
        .hint(run.title)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { actions.open(run) }
    }

    private var details: [String] {
        [run.branch, detail].compactMap { $0 }.filter { !$0.isEmpty }
    }

    private var detail: String {
        switch run.state {
        case .running:
            guard let jobs = run.jobs, jobs.total > 0 else { return String(localized: "Running") }
            let progress = String(localized: "\(jobs.done)/\(jobs.total) jobs")
            if jobs.failed > 0 { return progress + " · " + String(localized: "\(jobs.failed) failed") }
            return [progress, jobs.current].compactMap { $0 }.joined(separator: " · ")
        case .queued: return String(localized: "Queued")
        case .waiting: return String(localized: "Waiting for approval")
        case .passed: return String(localized: "Took \(Self.duration(run.updatedAt.timeIntervalSince(run.startedAt)))")
        case .failed: return String(localized: "Failed")
        case .cancelled: return String(localized: "Cancelled")
        case .skipped: return String(localized: "Skipped")
        }
    }

    private var detailColor: Color {
        switch run.state {
        case .failed: .red.opacity(0.85)
        case .waiting: .orange.opacity(0.9)
        case .running where (run.jobs?.failed ?? 0) > 0: .red.opacity(0.85)
        default: .textSecondary
        }
    }

    private var time: String {
        run.state.isActive ? run.startedAt.shortAge : run.updatedAt.shortAge
    }

    static func duration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        switch seconds {
        case ..<60: return "\(seconds)s"
        case ..<3600: return "\(seconds / 60)m \(seconds % 60)s"
        default: return "\(seconds / 3600)h \(seconds % 3600 / 60)m"
        }
    }
}

extension WorkflowRun {
    var dragItem: NSItemProvider {
        let provider = NSItemProvider(object: url as NSURL)
        provider.registerObject(url.absoluteString as NSString, visibility: .all)
        provider.suggestedName = "\(workflow) · \(repoName)"
        return provider
    }
}
