import SwiftUI

struct NotchRootView: View {
    @Environment(NotchInteraction.self) private var notch
    @Environment(AccountStore.self) private var accounts
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var lastShown: NotchState = .open

    var body: some View {
        let state = notch.state
        let size = notch.layout.size(for: state)
        let radii = notch.layout.radii(for: state)
        let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)

        VStack(spacing: 12) {
            panel(state: state, size: size, radii: radii, shape: shape)
            if state == .open, !accounts.accounts.isEmpty {
                AreaSwitcher()
                    .transition(.opacity.combined(with: .offset(y: -10)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .hintLayer(within: CGSize(width: size.width + radii.top * 2, height: size.height))
        .animation(Motion.peek, value: notch.liveCI)
        .environment(\.panelGlass, settings.panelStyle.usesGlass(reduceTransparency: reduceTransparency))
        .onChange(of: state) { _, new in
            if new != .closed { lastShown = new }
        }
    }

    private func background(state: NotchState, shape: NotchShape, height: CGFloat) -> some View {
        let glassState = state == .closed ? lastShown : state
        let glassSize = notch.layout.size(for: glassState)
        let glassRadii = notch.layout.radii(for: glassState)
        return NotchBackground(
            state: state,
            shape: shape,
            notchWidth: notch.geometry.notchSize.width,
            height: height,
            glassSize: CGSize(width: glassSize.width + glassRadii.top * 2, height: glassSize.height)
        )
    }

    private func panel(state: NotchState, size: CGSize, radii: (top: CGFloat, bottom: CGFloat), shape: NotchShape) -> some View {
        VStack(spacing: 0) {
            TopBar()
            if state == .peek, let alert = notch.peekAlert {
                PeekView(alert: alert) { notch.tapPeek(alert) }
                    .id(alert.id)
                    .transition(.reveal(delay: 0.08))
            }
            if state == .open {
                ExpandedView()
                    .transition(.reveal(delay: 0.07))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .padding(.horizontal, radii.top)
        .background { background(state: state, shape: shape, height: size.height) }
        .clipShape(shape)
        .compositingGroup()
        .shadow(color: .black.opacity(state == .closed ? 0 : 0.55), radius: state == .open ? 26 : 14, y: 8)
    }
}
