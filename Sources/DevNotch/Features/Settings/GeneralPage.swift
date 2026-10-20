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
                if let reason = settings.launchAtLoginFailure {
                    Text("Couldn't turn it on: \(reason). Install the app in /Applications.").font(.caption).foregroundStyle(.orange)
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
