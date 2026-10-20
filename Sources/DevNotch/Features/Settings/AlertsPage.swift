import AppKit
import SwiftUI

struct AlertsPage: View {
    @Environment(NotchInteraction.self) private var notch
    @Environment(AppSettings.self) private var settings
    @Environment(AccountStore.self) private var accounts
    @Environment(\.system) private var system

    var body: some View {
        Form {
            Section {
                Picker("Sound", selection: Binding(
                    get: { settings.sound ?? "" },
                    set: { name in
                        settings.sound = name.isEmpty ? nil : name
                        if let sound = settings.sound { system.play(sound: sound) }
                    }
                )) {
                    Text("None").tag("")
                    Divider()
                    ForEach(AppSettings.systemSounds, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Tap the trackpad", isOn: Binding(get: { settings.haptics }, set: { settings.haptics = $0 }))
                LabeledContent("Preview") {
                    Button("Send a test alert") { notch.previewAlert() }
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
