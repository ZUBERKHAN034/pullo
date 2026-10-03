import SwiftUI

struct AccountsView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore
    @ObservedObject var accounts: AccountStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    model.show(.accounts)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 10.5, weight: .bold))
                        Text("Accounts").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text(accounts.accounts.count == 1 ? "1 connected" : "\(accounts.accounts.count) connected")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(accounts.accounts) { account in
                        AccountRow(account: account, error: store.errors[account.login]) {
                            withAnimation(Motion.navigate) { accounts.remove(account) }
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
            }

            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            GHImportOptions(accounts: accounts)
                .frame(maxWidth: .infinity)
        }
        .onAppear { accounts.reloadGHUsers() }
    }
}

struct AccountRow: View {
    let account: Account
    let error: String?
    let onRemove: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Avatar(url: account.avatarURL, login: account.login, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("@\(account.login)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(error ?? "via GitHub CLI")
                    .font(.system(size: 11))
                    .foregroundStyle(error == nil ? .white.opacity(0.4) : .orange)
                    .lineLimit(1)
            }
            Spacer()
            IconButton(symbol: "trash", help: "Remove account", action: onRemove)
                .opacity(hovering ? 1 : 0.4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.white.opacity(hovering ? 0.06 : 0))
        )
        .onHover { hovering = $0 }
        .animation(Motion.hover, value: hovering)
    }
}
