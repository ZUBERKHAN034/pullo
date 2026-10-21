import SwiftUI

struct RunDetail: View {
    @Environment(ActionsModel.self) private var actions
    @Environment(NotchInteraction.self) private var notch
    let run: WorkflowRun

    @State private var confirmingCancel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolbar
            header
            jobs
        }
        .task(id: confirmingCancel) {
            guard confirmingCancel else { return }
            try? await Task.sleep(for: .seconds(3))
            confirmingCancel = false
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button {
                actions.back()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("Runs")
                }
                .font(.panel(.label, .semibold))
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .hint(String(localized: "Back to the runs"))
            Spacer()
            if canRerun {
                RunActionButton(
                    title: String(localized: "Re-run failed"),
                    symbol: "arrow.clockwise",
                    busy: actions.running == .rerunFailedJobs
                ) {
                    Task { await actions.perform(.rerunFailedJobs) }
                }
            }
            if run.state.isActive {
                RunActionButton(
                    title: confirmingCancel ? String(localized: "Cancel run?") : String(localized: "Cancel"),
                    symbol: "stop.fill",
                    tint: confirmingCancel ? .red : nil,
                    busy: actions.running == .cancel
                ) {
                    if confirmingCancel {
                        confirmingCancel = false
                        Task { await actions.perform(.cancel) }
                    } else {
                        confirmingCancel = true
                    }
                }
            }
            RunActionButton(title: String(localized: "Open on GitHub"), symbol: "arrow.up.right") {
                notch.openInBrowser(run.url)
            }
        }
        .glassGroup(spacing: 6)
    }

    private var canRerun: Bool {
        guard !run.state.isActive else { return false }
        return run.state == .failed || (actions.openedJobs?.contains(where: \.isFailed) ?? false)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            RunStatusIcon(run: run, size: 18)
                .frame(width: 18)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(run.workflow)
                        .font(.panel(.title, .semibold))
                        .foregroundStyle(.textStrong)
                    Text(verbatim: run.pullRequest.map { "\(run.repoName) #\($0)" } ?? run.repoName)
                        .font(.panel(.title))
                        .foregroundStyle(.textTertiary)
                }
                .lineLimit(1)
                if !run.title.isEmpty {
                    Text(run.title)
                        .font(.panel(.small))
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
                Text(facts.joined(separator: " · "))
                    .font(.panel(.small))
                    .foregroundStyle(.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
    }

    private var facts: [String] {
        var facts = [run.branch, run.actor.map { "@\($0)" }].compactMap { $0 }.filter { !$0.isEmpty }
        if run.state.isActive {
            facts.append(String(localized: "started \(run.startedAt.shortAge) ago"))
        } else {
            facts.append(RunRow.duration(run.updatedAt.timeIntervalSince(run.startedAt)))
        }
        return facts
    }

    // MARK: - Jobs

    @ViewBuilder
    private var jobs: some View {
        if let list = actions.openedJobs {
            if list.isEmpty {
                MessageView(
                    symbol: "square.stack.3d.up.slash",
                    title: String(localized: "No jobs yet"),
                    detail: String(localized: "GitHub hasn't started any job for this run.")
                )
            } else {
                ScrollView {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(JobGroup.grouping(list)) { group in
                                JobGroupView(group: group, now: context.date)
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        } else if let error = actions.openedJobsError {
            MessageView(symbol: "key.slash", title: String(localized: "Can't load the jobs"), detail: error) {
                Task { await actions.store.loadJobs(of: run) }
            }
        } else {
            MessageView(
                symbol: "square.stack.3d.up",
                title: String(localized: "Loading the jobs…"),
                detail: String(localized: "Asking GitHub what this run is doing.")
            )
        }
    }
}

private struct JobGroupView: View {
    let group: JobGroup
    let now: Date

    @State private var toggled = false

    private var isExpanded: Bool { (group.state == .failed || group.state == .running) != toggled }

    var body: some View {
        if group.isMatrix {
            Button {
                withAnimation(Motion.navigate) { toggled.toggle() }
            } label: {
                JobLine(
                    state: group.state,
                    name: group.name,
                    detail: summary,
                    trailing: nil,
                    chevron: isExpanded ? "chevron.down" : "chevron.right"
                )
            }
            .buttonStyle(.plain)
            if isExpanded {
                ForEach(group.jobs) { JobRow(job: $0, now: now, title: matrixName($0)).padding(.leading, 18) }
            }
        } else if let job = group.jobs.first {
            JobRow(job: job, now: now, title: job.name)
        }
    }

    private var summary: String {
        let failed = group.jobs.filter(\.isFailed).count
        let count = String(localized: "\(group.jobs.count) jobs")
        return failed > 0 ? count + " · " + String(localized: "\(failed) failed") : count
    }

    private func matrixName(_ job: WorkflowJob) -> String {
        guard job.name.hasPrefix(group.name + " (") else { return job.name }
        return String(job.name.dropFirst(group.name.count + 2).dropLast())
    }
}

private struct JobRow: View {
    @Environment(NotchInteraction.self) private var notch
    let job: WorkflowJob
    let now: Date
    let title: String

    @State private var toggled = false

    private var hasSteps: Bool { !job.steps.isEmpty }

    private var isExpanded: Bool { hasSteps && (job.state == .failed || job.state == .running) != toggled }

    var body: some View {
        Button {
            if hasSteps {
                withAnimation(Motion.navigate) { toggled.toggle() }
            } else if let url = job.url {
                notch.openInBrowser(url)
            }
        } label: {
            JobLine(
                state: job.state,
                name: title,
                detail: isExpanded ? nil : detail,
                trailing: duration,
                chevron: hasSteps ? (isExpanded ? "chevron.down" : "chevron.right") : nil
            )
        }
        .buttonStyle(.plain)
        .disabled(!hasSteps && job.url == nil)
        .hint(hint)
        if isExpanded {
            ForEach(job.steps) { step in
                StepRow(step: step, now: now, url: url(of: step))
            }
            .padding(.leading, 20)
        }
    }

    private var hint: String {
        if !hasSteps { return String(localized: "Open the job log") }
        return isExpanded ? String(localized: "Hide the steps") : String(localized: "Show the steps")
    }

    private var detail: String? {
        if let step = job.failedStep { return String(localized: "Failed at \(step)") }
        if job.state == .running { return job.currentStep }
        return nil
    }

    private var duration: String? {
        guard job.state != .skipped else { return nil }
        return job.duration(now: now).map(RunRow.duration)
    }

    private func url(of step: WorkflowStep) -> URL? {
        guard let url = job.url else { return nil }
        return URL(string: url.absoluteString + "#step:\(step.number):1")
    }
}

private struct StepRow: View {
    @Environment(NotchInteraction.self) private var notch
    let step: WorkflowStep
    let now: Date
    let url: URL?

    @State private var hovering = false

    var body: some View {
        Button {
            if let url { notch.openInBrowser(url) }
        } label: {
            HStack(spacing: 8) {
                JobStatusIcon(state: step.state, size: 10)
                Text(step.name)
                    .font(.panel(.small, step.state == .running || step.state == .failed ? .semibold : .regular))
                    .foregroundStyle(color)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let duration = step.duration(now: now) {
                    Text(RunRow.duration(duration))
                        .font(.panel(.small).monospacedDigit())
                        .foregroundStyle(.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hovering ? Color.surfaceSubtle : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
        .hint(String(localized: "Open the log at this step"))
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
    }

    private var color: Color {
        switch step.state {
        case .failed: Color.red.opacity(0.9)
        case .running: .textStrong
        case .skipped, .cancelled, .queued: .textTertiary
        default: .textSecondary
        }
    }
}

private struct JobLine: View {
    let state: WorkflowRun.State
    let name: String
    let detail: String?
    let trailing: String?
    let chevron: String?

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            JobStatusIcon(state: state)
            Text(name)
                .font(.panel(.label, .medium))
                .foregroundStyle(state == .skipped || state == .cancelled ? .textTertiary : .textStrong)
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.panel(.small))
                    .foregroundStyle(state == .failed ? Color.red.opacity(0.85) : .textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.panel(.small, .medium).monospacedDigit())
                    .foregroundStyle(.textSecondary)
            }
            if let chevron {
                Image(systemName: chevron)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.textTertiary)
                    .frame(width: 12)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(hovering ? Color.surfaceSubtle : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
    }
}

private struct JobStatusIcon: View {
    let state: WorkflowRun.State
    var size: CGFloat = 12

    var body: some View {
        Group {
            switch state {
            case .running: StatusIcon(status: .ciRunning, size: size)
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

private struct RunActionButton: View {
    @Environment(\.panelGlass) private var glass
    let title: String
    let symbol: String
    var tint: Color?
    var busy = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if busy {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .bold))
                }
                Text(title)
            }
            .font(.panel(.small, .semibold))
            .foregroundStyle(tint ?? .textStrong)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                if !glass {
                    Capsule().fill(hovering ? Color.surfaceStrong : .surface)
                }
            }
            .panelGlass(in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
        .animation(Motion.hover, value: tint)
    }
}
