import SwiftUI

struct TopBar: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore
    @ObservedObject var accounts: AccountStore

    var body: some View {
        let notch = model.geometry.notchSize
        ZStack {
            if model.state == .open {
                HStack(spacing: 0) {
                    AccountSwitcher(model: model, store: store, accounts: accounts, tracker: model.tracker)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: notch.width)
                    HeaderActions(model: model, store: store)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .frame(width: model.layout.size(for: .open).width)
                .transition(.reveal(delay: 0.1))
            }
        }
        .frame(height: notch.height)
    }
}
