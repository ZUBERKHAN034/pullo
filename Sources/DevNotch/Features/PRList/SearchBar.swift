import AppKit
import SwiftUI

struct SearchBar: View {
    @Environment(PRListModel.self) private var list
    @Environment(\.panelGlass) private var glass

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.panel(.label, .semibold))
                .foregroundStyle(.textTertiary)
            SearchField(text: Binding(get: { list.searchQuery }, set: { list.searchQuery = $0 }))
                .frame(height: 18)
            Button {
                list.stopSearch()
            } label: {
                KeyCap(key: "esc")
            }
            .buttonStyle(.plain)
            .hint(String(localized: "Close search"))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background {
            if !glass {
                Capsule().fill(.surfaceSubtle)
                    .overlay(Capsule().strokeBorder(.hairline, lineWidth: 1))
            }
        }
        .panelGlass(in: Capsule(), interactive: false)
    }
}
