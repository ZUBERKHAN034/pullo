import SwiftUI

struct Toast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.panel(.body, .semibold))
            .foregroundStyle(.black)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }
}
