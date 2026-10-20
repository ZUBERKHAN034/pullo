import AppKit
import SwiftUI

struct SearchBar: View {
    @ObservedObject var model: NotchViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            SearchField(text: Binding(get: { model.searchQuery }, set: { model.searchQuery = $0 }))
                .frame(height: 18)
            Button {
                model.stopSearch()
            } label: {
                Text("esc")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .hint("Close search", edge: .leading)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}
