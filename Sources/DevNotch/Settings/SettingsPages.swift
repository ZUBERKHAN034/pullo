import AppKit
import SwiftUI

struct GeneralPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }
            Section {
                LabeledContent("Quit DevNotch") {
                    Button("Quit", role: .destructive) { NSApp.terminate(nil) }
                }
            } footer: {
                Text("DevNotch lives in the notch and has no Dock icon, so this is the way to quit it.")
            }
        }
    }
}

struct AlertsPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var accounts: AccountStore
    let model: NotchViewModel

    var body: some View {
        Form {
            Section {
                Picker("Sound", selection: Binding(
                    get: { settings.sound ?? "" },
                    set: { name in
                        settings.sound = name.isEmpty ? nil : name
                        settings.playSound()
                    }
                )) {
                    Text("None").tag("")
                    Divider()
                    ForEach(AppSettings.systemSounds, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Tap the trackpad", isOn: Binding(get: { settings.haptics }, set: { settings.haptics = $0 }))
                LabeledContent("Preview") {
                    Button("Send a test alert") { model.previewAlert() }
                }
            } footer: {
                Text("Alerts drop down from the notch when something changes on a PR.")
            }

            Section("Alert me when") {
                ForEach(AlertCategory.allCases, id: \.self) { category in
                    Toggle(category.title, isOn: Binding(
                        get: { !settings.mutedCategories.contains(category) },
                        set: { enabled in
                            if enabled == settings.mutedCategories.contains(category) { settings.toggle(category) }
                        }
                    ))
                }
            }

            if accounts.accounts.count > 1 {
                Section("Accounts") {
                    ForEach(accounts.accounts) { account in
                        Toggle("@\(account.login)", isOn: Binding(
                            get: { !settings.mutedAccounts.contains(account.login) },
                            set: { enabled in
                                if enabled == settings.mutedAccounts.contains(account.login) {
                                    settings.toggleAccount(account.login)
                                }
                            }
                        ))
                    }
                }
            }
        }
    }
}

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
                if let message = accounts.importError {
                    Text(message).font(.caption).foregroundStyle(.orange)
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

struct ShortcutsPage: View {
    var body: some View {
        Form {
            Section {
                row("Open or close the panel", Shortcut.togglePanel.symbols)
            } header: {
                Text("Anywhere")
            } footer: {
                Text("Opening it from the keyboard selects the first PR, so you can go straight to the arrow keys.")
            }
            Section("In the panel") {
                row("Move through PRs", "↑ ↓")
                row("Open the selected PR", "↩")
                row("Switch between My PRs and To review", "⇥  or  ← →")
                row("Filter PRs", "⌘F")
                row("Copy the branch name", "C")
                row("Mark as read", "R")
                row("Switch account", "⌘1 – ⌘9")
                row("Clear the filter, or close", "esc")
                row("Quit DevNotch", "⌘Q")
            }
        }
    }

    private func row(_ action: String, _ keys: String) -> some View {
        LabeledContent(action) {
            Text(keys)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct UpdatesPage: View {
    @ObservedObject var updater: Updater

    var body: some View {
        Form {
            Section {
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updater.automaticallyChecks },
                    set: { updater.automaticallyChecks = $0 }
                ))
                LabeledContent("Version \(Updater.version)") {
                    Button("Check Now") { updater.checkForUpdates() }
                        .disabled(!updater.canCheckForUpdates)
                }
            } footer: {
                Text("Updates are signed and notarized by Apple, and installed when you quit DevNotch.")
            }
        }
    }
}

struct AboutPage: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DevNotch").font(.title3.weight(.semibold))
                        Text("Version \(Updater.version)").foregroundStyle(.secondary)
                        Text("Your GitHub pull requests in the notch.").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                Link("Source code on GitHub", destination: URL(static: "https://github.com/jordan-cod/devnotch"))
                Link("Report an issue", destination: URL(static: "https://github.com/jordan-cod/devnotch/issues/new"))
                LabeledContent("License", value: "MIT")
            }
        }
    }
}
