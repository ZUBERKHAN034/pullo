import SwiftUI

struct TopBar: View {
    @Environment(NotchInteraction.self) private var notch

    var body: some View {
        let notchSize = notch.geometry.notchSize
        ZStack {
            if notch.state == .open {
                HStack(spacing: 0) {
                    AccountSwitcher()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: notchSize.width)
                    HeaderActions()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .frame(width: notch.layout.size(for: .open).width)
                .transition(.reveal(delay: 0.1))
            }
        }
        .frame(height: notchSize.height)
    }
}
