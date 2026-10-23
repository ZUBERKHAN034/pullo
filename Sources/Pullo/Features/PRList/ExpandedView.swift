import SwiftUI

struct ExpandedView: View {
    @Environment(ToastCenter.self) private var toasts
    @Environment(NotchInteraction.self) private var notch
    @Environment(AccountStore.self) private var accounts

    var body: some View {
        let size = notch.layout.size(for: .open)
        ZStack(alignment: .top) {
            if accounts.accounts.isEmpty {
                OnboardingView()
                    .transition(.reveal(delay: 0.05))
            } else if notch.area == .actions {
                ActionsBrowser()
                    .transition(.opacity)
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
            if let message = toasts.message {
                Toast(message: message)
                    .padding(.bottom, 14)
                    .transition(.fadeSlide(from: .bottom))
            }
        }
    }
}
