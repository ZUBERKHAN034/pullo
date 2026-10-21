import SwiftUI

struct ProgressRing: View {
    let fraction: Double
    var size: CGFloat = 14
    var color: Color = .yellow

    var body: some View {
        let line = max(1.5, size / 5.6)
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: line)
            Circle()
                .trim(from: 0, to: max(fraction, 0.04))
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.reveal, value: fraction)
        }
        .frame(width: size, height: size)
    }
}
