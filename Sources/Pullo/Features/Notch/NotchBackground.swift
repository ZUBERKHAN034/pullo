import SwiftUI

struct NotchBackground<S: Shape>: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let state: NotchState
    let shape: S
    let notchWidth: CGFloat
    let height: CGFloat
    var style: PanelStyle?
    var scale: CGFloat = 1
    var glassSize: CGSize?

    private var currentStyle: PanelStyle { style ?? settings.panelStyle }

    var body: some View {
        if usesGlass, #available(macOS 26, *) {
            ZStack {
                glass
                if currentStyle == .glassDarkTop {
                    darkTop
                }
                Color.black.opacity(state == .closed ? 1 : 0)
            }
        } else {
            Color.black
        }
    }

    @available(macOS 26, *)
    @ViewBuilder
    private var glass: some View {
        if let glassSize {
            Color.clear
                .glassEffect(.regular, in: Rectangle())
                .frame(width: glassSize.width, height: glassSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transaction { $0.animation = nil }
        } else {
            Color.clear.glassEffect(.regular, in: shape)
        }
    }

    private var darkTop: some View {
        RadialGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: blackRadius / fadeRadius),
                .init(color: .black.opacity(0), location: 1),
            ],
            center: .top,
            startRadius: 0,
            endRadius: fadeRadius
        )
    }

    private var blackRadius: CGFloat { notchWidth / 2 + 24 * scale }
    private var fadeRadius: CGFloat { max(blackRadius + 120 * scale, height * 1.2) }

    private var usesGlass: Bool {
        currentStyle.usesGlass(reduceTransparency: reduceTransparency)
    }
}
