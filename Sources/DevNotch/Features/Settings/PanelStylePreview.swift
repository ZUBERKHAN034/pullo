import SwiftUI

struct PanelStylePreview: View {
    let style: PanelStyle

    var body: some View {
        ZStack(alignment: .top) {
            PreviewWallpaper()
            panel
        }
    }

    private var panel: some View {
        let shape = NotchShape(topRadius: 4, bottomRadius: 10)
        return VStack(alignment: .leading, spacing: 6) {
            Color.clear.frame(height: 10)
            ForEach(0..<3) { row in
                HStack(spacing: 5) {
                    Circle().fill(row == 1 ? Color.red : Color.green).frame(width: 6, height: 6)
                    Capsule().fill(Color.white.opacity(0.85)).frame(width: [54, 44, 60][row], height: 4)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 104, height: 62, alignment: .top)
        .background {
            NotchBackground(state: .open, shape: shape, notchWidth: 34, height: 62, style: style, scale: 0.18)
        }
        .clipShape(shape)
    }
}
