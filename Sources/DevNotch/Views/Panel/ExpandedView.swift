import SwiftUI

/// Everything below the notch when the panel is open: onboarding or the PRs, with toasts over them.
struct ExpandedView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore
    @ObservedObject var accounts: AccountStore
    @ObservedObject var tracker: ReadTracker

    var body: some View {
        let size = model.layout.size(for: .open)
        ZStack(alignment: .top) {
            if accounts.accounts.isEmpty {
                OnboardingView(accounts: accounts)
                    .transition(.reveal(delay: 0.05))
            } else {
                PRBrowser(model: model, store: store, tracker: tracker)
                    .transition(.reveal(delay: 0.05))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .frame(width: size.width, height: size.height - model.geometry.notchSize.height, alignment: .top)
        .overlay(alignment: .bottom) {
            if let message = model.toast {
                Toast(message: message)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
