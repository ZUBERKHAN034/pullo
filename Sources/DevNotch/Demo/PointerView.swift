import AppKit
import SwiftUI

#if DEBUG
    struct PointerView: View {
        @ObservedObject var model: DemoStageModel

        var body: some View {
            ArrowShape()
                .fill(.black)
                .overlay(ArrowShape().stroke(.white, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round)))
                .frame(width: 17, height: 25)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                .position(x: model.cursor.x + 6, y: model.cursor.y + 11)
                .opacity(model.cursorVisible ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private struct ArrowShape: Shape {
        func path(in rect: CGRect) -> Path {
            let w = rect.width, h = rect.height
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: h * 0.78))
            path.addLine(to: CGPoint(x: w * 0.27, y: h * 0.6))
            path.addLine(to: CGPoint(x: w * 0.47, y: h))
            path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.93))
            path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.55))
            path.addLine(to: CGPoint(x: w, y: h * 0.55))
            path.closeSubpath()
            return path
        }
    }
#endif
