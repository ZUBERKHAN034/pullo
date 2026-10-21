import SwiftUI

struct AccountStack: View {
    @Environment(AccountStore.self) private var accounts
    @Environment(NotchInteraction.self) private var notch

    var body: some View {
        if accounts.accounts.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.pull")
                    .font(.panel(.small, .semibold))
                Text("Pullo")
                    .font(.panel(.label, .semibold))
            }
            .foregroundStyle(.textStrong)
        } else {
            Button {
                notch.onOpenSettings?(.accounts)
            } label: {
                HStack(spacing: 6) {
                    HStack(spacing: -6) {
                        ForEach(accounts.accounts) { account in
                            Avatar(url: account.avatarURL, login: account.login, size: 18)
                                .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 1.5))
                        }
                    }
                    Text(verbatim: label)
                        .font(.panel(.body, .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.textStrong)
                .padding(.leading, 3)
                .padding(.trailing, 9)
                .padding(.vertical, 3)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .hint(accounts.accounts.map { "@\($0.login)" }.joined(separator: " · "))
        }
    }

    private var label: String {
        guard accounts.accounts.count > 1 else { return accounts.accounts[0].login }
        return String(localized: "\(accounts.accounts.count) accounts")
    }
}
