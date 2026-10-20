import AppKit
import SwiftUI

struct AccountsPage: View {
    @ObservedObject var accounts: AccountStore
    @State private var removing: Account?

    var body: some View {
        Form {
            Section {
                if accounts.accounts.isEmpty {
                    Text("No accounts yet.").foregroundStyle(.secondary)
                }
                ForEach(accounts.accounts) { account in
                    LabeledContent {
                        Button("Remove…") { removing = account }
                    } label: {
                        HStack(spacing: 10) {
                            Avatar(url: account.avatarURL, login: account.login, size: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("@\(account.login)")
                                Text("via GitHub CLI").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Connected")
            } footer: {
                Text("DevNotch reads tokens from the GitHub CLI when it needs them and never stores them.")
            }

            Section("Add from GitHub CLI") {
                if !accounts.ghInstalled {
                    Text(.init("Install GitHub CLI with `brew install gh`, then run `gh auth login`."))
                        .foregroundStyle(.secondary)
                } else if accounts.importableGHUsers.isEmpty {
                    Text(.init("Every gh account is added. Run `gh auth login` in Terminal to log into another one."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accounts.importableGHUsers, id: \.self) { user in
                        LabeledContent("@\(user)") {
                            if accounts.importing == user {
                                ProgressView().controlSize(.small)
                            } else {
                                Button("Add") { Task { await accounts.importFromGH(user) } }
                            }
                        }
                    }
                }
                if let failure = accounts.importFailure {
                    Text(failure.message).font(.caption).foregroundStyle(.orange)
                }
                LabeledContent("Logged in with gh just now?") {
                    Button("Check again") { accounts.reloadGHUsers() }
                }
            }
        }
        .onAppear { accounts.reloadGHUsers() }
        .confirmationDialog(
            "Remove @\(removing?.login ?? "")?",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            presenting: removing
        ) { account in
            Button("Remove", role: .destructive) { accounts.remove(account) }
        } message: { _ in
            Text("Its PRs leave the notch. You can add it back from the GitHub CLI any time.")
        }
    }
}
