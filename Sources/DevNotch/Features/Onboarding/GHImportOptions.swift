import SwiftUI

struct GHImportOptions: View {
    @Environment(AccountStore.self) private var accounts

    var body: some View {
        VStack(spacing: 8) {
            let importable = accounts.importableGHUsers
            if !accounts.ghInstalled {
                hint("Install GitHub CLI with `brew install gh`, then run `gh auth login`.")
            } else if importable.isEmpty {
                hint(accounts.accounts.isEmpty
                    ? "No account is logged into gh. Run `gh auth login` in Terminal."
                    : "To add another account, run `gh auth login` and check again.")
            } else {
                HStack(spacing: 8) {
                    ForEach(importable, id: \.self) { user in
                        PillButton(
                            title: "Add @\(user)",
                            symbol: "plus",
                            prominent: true,
                            loading: accounts.importing == user
                        ) {
                            Task { await accounts.importFromGH(user) }
                        }
                    }
                }
            }
            if importable.isEmpty {
                PillButton(title: "Check again", symbol: "arrow.clockwise") { accounts.reloadGHUsers() }
            }
            if let failure = accounts.importFailure {
                Text(failure.message).font(.panel(.small)).foregroundStyle(.orange).lineLimit(2)
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(.init(text))
            .font(.panel(.body))
            .foregroundStyle(.textSecondary)
            .multilineTextAlignment(.center)
    }
}
