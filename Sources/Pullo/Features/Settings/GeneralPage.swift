import AppKit
import SwiftUI

struct GeneralPage: View {
    @Environment(\.system) private var system
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("Show on", selection: $settings.display) {
                    ForEach(DisplayChoice.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } footer: {
                Text(
                    "Built-in display uses the notch when there is one. Display with the pointer moves Pullo to the screen you're working on."
                )
            }
            Section {
                Toggle("Open Pullo on hover", isOn: $settings.opensOnHover)
            } footer: {
                Text("Turn this off if another app uses the notch. You can still open Pullo with its keyboard shortcut or by clicking the notch.")
            }
            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let reason = settings.launchAtLoginFailure {
                    Text("Couldn't turn it on: \(reason). Install the app in /Applications.").font(.caption).foregroundStyle(.orange)
                }
            }
            Section {
                LabeledContent("Quit Pullo") {
                    Button("Quit", role: .destructive) { system.quit() }
                }
            } footer: {
                Text("Pullo lives in the notch and has no Dock icon, so this is the way to quit it.")
            }
        }
    }
}
