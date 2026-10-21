import SwiftUI

struct ActionsBrowser: View {
    @Environment(ActionsModel.self) private var actions
    @Namespace private var selection

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(RunFilter.allCases, id: \.self) { filter in
                    filterButton(filter)
                }
                Spacer()
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if !actions.isLoaded, let error = actions.error {
            MessageView(symbol: "key.slash", title: String(localized: "Can't reach GitHub"), detail: error) {
                Task { await actions.store.refresh() }
            }
        } else if !actions.isLoaded {
            MessageView(
                symbol: "bolt.horizontal.circle",
                title: String(localized: "Looking for your runs…"),
                detail: String(localized: "Checking the repositories you pushed to and your open pull requests.")
            )
        } else if actions.active.isEmpty, actions.recent.isEmpty {
            MessageView(symbol: "bolt.horizontal.circle", title: String(localized: "No runs here"), detail: emptyDetail)
                .id(actions.filter)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    section(String(localized: "Running"), actions.active)
                    section(String(localized: "Recent"), actions.recent)
                }
            }
            .scrollIndicators(.never)
            .id(actions.filter)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ runs: [WorkflowRun]) -> some View {
        if !runs.isEmpty {
            Text(title.uppercased())
                .font(.panel(.caption, .bold))
                .foregroundStyle(.textMuted)
                .padding(.horizontal, 10)
                .padding(.top, 4)
            ForEach(runs) { RunRow(run: $0) }
        }
    }

    private var emptyDetail: String {
        switch actions.filter {
        case .mine: String(localized: "Workflow runs you start in the repositories you work on show up here.")
        case .everyone: String(localized: "Workflow runs from the repositories you work on show up here.")
        case .deploys: String(localized: "Runs of workflows with “deploy” in their name show up here.")
        }
    }

    private func filterButton(_ filter: RunFilter) -> some View {
        let selected = actions.filter == filter
        let active = actions.activeCount(in: filter)
        return Button {
            actions.select(filter)
        } label: {
            HStack(spacing: 6) {
                Text(filter.title)
                if active > 0 {
                    HStack(spacing: 3) {
                        StatusIcon(status: .ciRunning, size: 10)
                        Text(verbatim: "\(active)")
                    }
                    .font(.panel(.caption, .bold, design: .rounded))
                    .foregroundStyle(selected ? .textStrong : .textSecondary)
                }
            }
            .font(.panel(.label, .semibold))
            .foregroundStyle(selected ? Color.white : .textTertiary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                if selected {
                    Capsule()
                        .fill(.surface)
                        .matchedGeometryEffect(id: "filter", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
