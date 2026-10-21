import SwiftUI

struct AccountMark: View {
    @Environment(AccountStore.self) private var accounts
    let login: String

    var body: some View {
        if accounts.accounts.count > 1, let account = accounts.accounts.first(where: { $0.login == login }) {
            Avatar(url: account.avatarURL, login: account.login, size: 13)
                .hint("@\(account.login)")
        }
    }
}
