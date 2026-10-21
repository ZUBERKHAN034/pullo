import SwiftUI

struct Toast: View {
    @Environment(\.panelGlass) private var glass
    let message: String

    var body: some View {
        let text = Text(message)
            .font(.panel(.body, .semibold))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        if glass {
            text
                .foregroundStyle(.white)
                .panelGlass(in: Capsule(), interactive: false)
        } else {
            text
                .foregroundStyle(.black)
                .background(Capsule().fill(.white))
                .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
        }
    }
}
