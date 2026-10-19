import SwiftUI

/// The CI state of a PR's latest commit: a glowing dot with a check or a cross when it's done, a spinning ring
/// while it runs. The glyph means it doesn't rely on color alone.
struct CIStatusIcon: View {
    let state: CIState
    var size: CGFloat = 10

    var body: some View {
        switch state {
        case .success:
            dot(.green, glyph: "checkmark")
        case .failure:
            dot(.red, glyph: "xmark")
        case .pending:
            let line = max(1.6, size / 5.5)
            ZStack {
                Circle().stroke(Color.yellow.opacity(0.22), lineWidth: line)
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.yellow, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .spinning()
            }
            .frame(width: size - line, height: size - line)
            .frame(width: size, height: size)
        }
    }

    private func dot(_ color: Color, glyph: String) -> some View {
        Circle().fill(color).frame(width: size, height: size)
            .overlay(
                Image(systemName: glyph)
                    .font(.system(size: size * 0.55, weight: .black))
                    .foregroundStyle(.black.opacity(0.75))
            )
            .shadow(color: color.opacity(0.5), radius: 3)
    }
}
