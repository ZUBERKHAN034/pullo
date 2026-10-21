import SwiftUI

struct ActionsBrowser: View {
    @Environment(ActionsModel.self) private var actions
    @Environment(NotchInteraction.self) private var notch
    @Namespace private var selection

    var body: some View {
        if let run = actions.openedRun {
            RunDetail(run: run)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        } else {
            browser
                .transition(.opacity.combined(with: .move(edge: .leading)))
        }
    }

    private var browser: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(actions.tabs) { tab in
                            tabButton(tab)
                        }
                    }
                    .glassGroup(spacing: 4)
                }
                IconButton(symbol: "slider.horizontal.3", help: String(localized: "Edit the Actions tabs"), floating: true) {
                    notch.onOpenSettings?(.tabs)
                }
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
                .id(actions.tab?.id)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    section(String(localized: "Running"), actions.active)
                    section(String(localized: "Recent"), actions.recent)
                }
            }
            .scrollIndicators(.never)
            .id(actions.tab?.id)
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
        switch actions.tab?.preset {
        case .mine: String(localized: "Workflow runs you start in the repositories you work on show up here.")
        case .everyone: String(localized: "Workflow runs from the repositories you work on show up here.")
        case .deploys: String(localized: "Runs of workflows with “deploy” in their name show up here.")
        case nil: String(localized: "Runs that match this tab, in the repositories you work on, show up here.")
        }
    }

    private func tabButton(_ tab: RunTab) -> some View {
        let selected = actions.tab?.id == tab.id
        let active = actions.activeCount(in: tab)
        return Button {
            actions.select(tab)
        } label: {
            HStack(spacing: 6) {
                Text(tab.name)
                    .lineLimit(1)
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
                    SelectionCapsule()
                        .matchedGeometryEffect(id: "filter", in: selection)
                }
            }
            .panelGlass(selected, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
