import AppKit
import SwiftUI

struct SearchBar: View {
    @ObservedObject var model: NotchViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.panel(.label, .semibold))
                .foregroundStyle(.textTertiary)
            SearchField(text: Binding(get: { model.searchQuery }, set: { model.searchQuery = $0 }))
                .frame(height: 18)
            Button {
                model.stopSearch()
            } label: {
                KeyCap(key: "esc")
            }
            .buttonStyle(.plain)
            .hint("Close search", edge: .leading)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Capsule().fill(.surfaceSubtle))
        .overlay(Capsule().strokeBorder(.hairline, lineWidth: 1))
    }
}
