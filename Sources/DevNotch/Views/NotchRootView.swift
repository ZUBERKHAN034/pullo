import SwiftUI

struct NotchRootView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore
    @ObservedObject var accounts: AccountStore

    var body: some View {
        let state = model.state
        let size = model.layout.size(for: state)
        let radii = model.layout.radii(for: state)
        let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)

        VStack(spacing: 0) {
            TopBar(model: model, store: store, accounts: accounts)
            if state == .peek, let alert = model.peekAlert {
                PeekView(alert: alert) { model.tapPeek(alert) }
                    .id(alert.id)
                    .transition(.reveal(delay: 0.08))
            }
            if state == .open {
                ExpandedView(model: model, store: store, accounts: accounts, tracker: model.tracker)
                    .transition(.reveal(delay: 0.07))
            }
        }
        // Content keeps its final layout and the animated shape clips it, so it reads as uncovered, not stretched.
        .frame(width: size.width, height: size.height, alignment: .top)
        .padding(.horizontal, radii.top)
        .background(Color.black)
        .clipShape(shape)
        .compositingGroup()
        .shadow(color: .black.opacity(state == .closed ? 0 : 0.55), radius: state == .open ? 26 : 14, y: 8)
        .opacity(state == .closed && !model.geometry.hasNotch ? 0 : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
