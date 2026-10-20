import SwiftUI

struct AccountSwitcher: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore
    @ObservedObject var accounts: AccountStore
    @ObservedObject var tracker: ReadTracker
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 4) {
            if accounts.accounts.isEmpty {
                Image(systemName: "arrow.triangle.pull")
                    .font(.panel(.small, .semibold))
                Text("DevNotch")
                    .font(.panel(.label, .semibold))
            }
            ForEach(accounts.accounts) { account in
                let selected = account.login == model.currentLogin
                Button {
                    model.selectAccount(account.login)
                } label: {
                    HStack(spacing: 6) {
                        Avatar(url: account.avatarURL, login: account.login, size: 18)
                            .opacity(selected ? 1 : 0.55)
                            .overlay(alignment: .topTrailing) {
                                if !selected, hasUnread(account.login) {
                                    UnreadDot(size: 7)
                                        .overlay(Circle().stroke(.black, lineWidth: 1.5))
                                        .offset(x: 2, y: -2)
                                }
                            }
                        if selected {
                            Text(account.login)
                                .font(.panel(.body, .semibold))
                                .lineLimit(1)
                                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                        }
                    }
                    .padding(.leading, 3)
                    .padding(.trailing, selected ? 9 : 3)
                    .padding(.vertical, 3)
                    .background {
                        if selected {
                            Capsule()
                                .fill(.surfaceStrong)
                                .matchedGeometryEffect(id: "account", in: selection)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .hint("@\(account.login) · ⌘\((accounts.accounts.firstIndex(of: account) ?? 0) + 1)")
            }
        }
        .foregroundStyle(.textStrong)
    }

    private func hasUnread(_ login: String) -> Bool {
        (store.mine(for: login) + store.reviewRequests(for: login)).contains(where: tracker.isUnread)
    }
}
