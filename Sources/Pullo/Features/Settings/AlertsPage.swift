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

            Section {
                ForEach(AlertCategory.allCases, id: \.self) { category in
                    LabeledContent(category.title) {
                        HStack(spacing: 12) {
                            soundPicker(for: category)
                                .disabled(settings.mutedCategories.contains(category))
                            Toggle(category.title, isOn: Binding(
                                get: { !settings.mutedCategories.contains(category) },
                                set: { enabled in
                                    if enabled == settings.mutedCategories.contains(category) { settings.toggle(category) }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                    }
                }
            } header: {
                Text("Alert me when")
            } footer: {
                Text("Each kind of alert can play its own sound. Default uses the sound above.")
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

    private func soundPicker(for category: AlertCategory) -> some View {
        Picker(String(localized: "Sound for \(category.title)"), selection: Binding(
            get: { settings.categorySounds[category] },
            set: { name in
                settings.categorySounds[category] = name
                if let sound = settings.sound(for: category) { system.play(sound: sound) }
            }
        )) {
            Text("Default").tag(String?.none)
            Text("None").tag(String?.some(""))
            Divider()
            ForEach(AppSettings.systemSounds, id: \.self) { Text($0).tag(String?.some($0)) }
        }
        .labelsHidden()
        .fixedSize()
    }
}
