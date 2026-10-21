import SwiftUI

struct PreviewPicker<Option: Hashable, Preview: View>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    @ViewBuilder let preview: (Option) -> Preview

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(options, id: \.self) { option in
                card(for: option)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func card(for option: Option) -> some View {
        let isSelected = selection == option
        return Button {
            selection = option
        } label: {
            VStack(spacing: 8) {
                preview(option)
                    .frame(width: 136, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .environment(\.colorScheme, .dark)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                                lineWidth: isSelected ? 3 : 1
                            )
                    }
                Text(title(option))
                    .font(.callout)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 136)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title(option))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct PreviewWallpaper: View {
    var body: some View {
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
}
