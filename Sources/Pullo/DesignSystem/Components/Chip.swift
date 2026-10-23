import SwiftUI

struct Chip: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.panel(.caption, .semibold))
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(.surface))
    }
}
