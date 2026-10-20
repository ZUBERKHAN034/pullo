import SwiftUI

struct NotchBackground<S: Shape>: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let state: NotchState
    let shape: S
    let notchWidth: CGFloat
    let height: CGFloat

    var body: some View {
        if usesGlass, #available(macOS 26, *) {
            ZStack {
                Color.clear.glassEffect(.regular, in: shape)
                if settings.panelStyle == .glassDarkTop {
                    darkTop
                }
                Color.black.opacity(state == .closed ? 1 : 0)
            }
        } else {
            Color.black
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

    private var blackRadius: CGFloat { notchWidth / 2 + 24 }
    private var fadeRadius: CGFloat { max(blackRadius + 120, height * 1.2) }

    private var usesGlass: Bool {
        settings.panelStyle.isGlass && PanelStyle.glassIsAvailable && !reduceTransparency
    }
}
