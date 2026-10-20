import SwiftUI

struct ExpandedView: View {
    @Environment(PRListModel.self) private var list
    @Environment(NotchInteraction.self) private var notch
    @Environment(AccountStore.self) private var accounts

    var body: some View {
        let size = notch.layout.size(for: .open)
        ZStack(alignment: .top) {
            if accounts.accounts.isEmpty {
                OnboardingView()
                    .transition(.reveal(delay: 0.05))
            } else {
                PRBrowser()
                    .transition(.reveal(delay: 0.05))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .frame(width: size.width, height: size.height - notch.geometry.notchSize.height, alignment: .top)
        .overlay(alignment: .bottom) {
            if let message = list.toast {
                Toast(message: message)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
