import SwiftUI

struct KeyCap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.keycap)
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4).fill(.surface))
    }
}
