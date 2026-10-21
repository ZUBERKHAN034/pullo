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
            MessageView(
                symbol: "bolt.horizontal.circle",
                title: String(localized: "No runs yet"),
                detail: String(localized: "Workflow runs from your repositories will show up here.")
            )
        }
    }

    private func filterButton(_ filter: RunFilter) -> some View {
        let selected = actions.filter == filter
        return Button {
            actions.select(filter)
        } label: {
            Text(filter.title)
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
