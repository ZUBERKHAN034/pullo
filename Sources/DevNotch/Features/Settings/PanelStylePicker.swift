import SwiftUI

struct PanelStylePicker: View {
    @Binding var selection: PanelStyle

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(PanelStyle.allCases, id: \.self) { style in
                Button {
                    selection = style
                } label: {
                    VStack(spacing: 8) {
                        PanelStylePreview(style: style)
                            .overlay {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(
                                        selection == style ? Color.accentColor : Color.primary.opacity(0.12),
                                        lineWidth: selection == style ? 3 : 1
                                    )
                            }
                        Text(style.title)
                            .font(.callout)
                            .foregroundStyle(selection == style ? .primary : .secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 136)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.title)
                .accessibilityAddTraits(selection == style ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

private struct PanelStylePreview: View {
    let style: PanelStyle

    var body: some View {
        ZStack(alignment: .top) {
            wallpaper
            panel
        }
        .frame(width: 136, height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private var wallpaper: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.82, blue: 0.62),
                    Color(red: 0.93, green: 0.93, blue: 0.95),
                    Color(red: 0.6, green: 0.82, blue: 0.95),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 7) {
                ForEach(0..<6) { row in
                    HStack(spacing: 6) {
                        Capsule().fill(Color.black.opacity(0.35)).frame(width: row.isMultiple(of: 2) ? 70 : 52, height: 4)
                        Spacer()
                        Capsule().fill(row.isMultiple(of: 3) ? Color.green : Color.white).frame(width: 22, height: 7)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var panel: some View {
        let shape = NotchShape(topRadius: 4, bottomRadius: 10)
        return VStack(alignment: .leading, spacing: 6) {
            Color.clear.frame(height: 10)
            ForEach(0..<3) { row in
                HStack(spacing: 5) {
                    Circle().fill(row == 1 ? Color.red : Color.green).frame(width: 6, height: 6)
                    Capsule().fill(Color.white.opacity(0.85)).frame(width: [54, 44, 60][row], height: 4)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 104, height: 62, alignment: .top)
        .background {
            NotchBackground(state: .open, shape: shape, notchWidth: 34, height: 62, style: style, scale: 0.18)
        }
        .clipShape(shape)
    }
}
