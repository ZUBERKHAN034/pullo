import SwiftUI

struct NotchRootView: View {
    @Environment(NotchInteraction.self) private var notch

    var body: some View {
        let state = notch.state
        let size = notch.layout.size(for: state)
        let radii = notch.layout.radii(for: state)
        let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)

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
        .background { NotchBackground(state: state, shape: shape, notchWidth: notch.geometry.notchSize.width, height: size.height) }
        .clipShape(shape)
        .compositingGroup()
        .shadow(color: .black.opacity(state == .closed ? 0 : 0.55), radius: state == .open ? 26 : 14, y: 8)
        .opacity(state == .closed && !notch.geometry.hasNotch ? 0 : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
