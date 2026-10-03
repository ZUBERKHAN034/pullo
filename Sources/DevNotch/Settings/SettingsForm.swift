import AppKit
import SwiftUI

struct SettingsForm: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var accounts: AccountStore
    let model: NotchViewModel

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
                Toggle("Tap the trackpad on new alerts", isOn: Binding(
                    get: { settings.haptics },
                    set: { settings.haptics = $0 }
                ))
            }

            Section("Shortcuts") {
                LabeledContent("Open the panel", value: "⌥⌘P")
                LabeledContent("Search PRs", value: "⌘F with the panel open")
            }

            Section {
                ForEach(AlertCategory.allCases, id: \.self) { category in
                    Toggle(category.title, isOn: Binding(
                        get: { !settings.mutedCategories.contains(category) },
                        set: { enabled in
                            if enabled == settings.mutedCategories.contains(category) { settings.toggle(category) }
                        }
                    ))
                }
            } header: {
                Text("Alerts")
            } footer: {
                Text("Alerts drop down from the notch when something changes on a PR.")
            }

            if accounts.accounts.count > 1 {
                Section("Alerts by account") {
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

            Section {
                HStack {
                    Button("Test alert") { model.previewAlert() }
                    Spacer()
                    Button("Quit DevNotch", role: .destructive) { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .frame(width: 480, height: 600)
    }
}
