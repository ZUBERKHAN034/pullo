import SwiftUI

struct AlertIcon: View {
    let alert: NotchAlert
    var size: CGFloat = 30

    var body: some View {
        icon.accessibilityHidden(true)
    }

    @ViewBuilder
    private var icon: some View {
        if let actor = alert.actor {
            Avatar(url: alert.actorAvatar, login: actor, size: size)
                .overlay(alignment: .bottomTrailing) {
                    badge(size * 0.56)
                        .overlay(Circle().stroke(.black, lineWidth: 2))
                        .offset(x: size * 0.1, y: size * 0.1)
                }
        } else {
            badge(size)
        }
    }

    private func badge(_ diameter: CGFloat) -> some View {
        ZStack {
            Circle().fill(.black)
            Circle().fill(alert.tint.opacity(alert.actor == nil ? 0.2 : 0.35))
            Image(systemName: alert.symbol)
                .resizable()
                .scaledToFit()
                .fontWeight(.bold)
                .frame(width: diameter * 0.62, height: diameter * 0.42)
                .foregroundStyle(alert.tint)
        }
        .frame(width: diameter, height: diameter)
    }
}
