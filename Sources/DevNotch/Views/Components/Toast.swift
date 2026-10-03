import SwiftUI

/// A short confirmation that something happened, e.g. a branch name was copied.
struct Toast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.black)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }
}
