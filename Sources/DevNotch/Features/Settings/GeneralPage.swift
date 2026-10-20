import AppKit
import SwiftUI

struct GeneralPage: View {
    @Environment(\.system) private var system
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            if PanelStyle.glassIsAvailable {
                Section {
                    Picker("Appearance", selection: $settings.panelStyle) {
                        ForEach(PanelStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } footer: {
                    Text("Glass follows your Liquid Glass setting, and turns solid when Reduce transparency is on.")
                }
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
                LabeledContent("Quit DevNotch") {
                    Button("Quit", role: .destructive) { system.quit() }
                }
            } footer: {
                Text("DevNotch lives in the notch and has no Dock icon, so this is the way to quit it.")
            }
        }
    }
}
