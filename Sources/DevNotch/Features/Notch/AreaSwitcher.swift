import SwiftUI

struct AreaSwitcher: View {
    @Environment(NotchInteraction.self) private var notch
    @Environment(ActionsModel.self) private var actions
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PanelArea.allCases, id: \.self) { area in
                button(for: area)
            }
        }
        .padding(3)
        .background { SwitcherBackground() }
        .panelGlass(in: Capsule())
    }

    private var running: Int { actions.activeCount(in: .mine) }

    private func button(for area: PanelArea) -> some View {
        let selected = notch.area == area
        return Button {
            notch.show(area)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: area.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(area.title)
                    .font(.panel(.label, .semibold))
                if area == .actions, running > 0 {
                    HStack(spacing: 3) {
                        StatusIcon(status: .ciRunning, size: 10)
                        Text(verbatim: "\(running)")
                    }
                    .font(.panel(.caption, .bold, design: .rounded))
                    .foregroundStyle(selected ? .textStrong : .textSecondary)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .animation(Motion.navigate, value: running)
            .foregroundStyle(selected ? Color.white : .textTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if selected {
                    Capsule()
                        .fill(.surfaceStrong)
                        .matchedGeometryEffect(id: "area", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct SwitcherBackground: View {
    @Environment(\.panelGlass) private var glass

    var body: some View {
        if !glass {
            Capsule()
                .fill(Color.black)
                .overlay(Capsule().strokeBorder(Color.hairline))
                .compositingGroup()
                .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
        }
    }
}
