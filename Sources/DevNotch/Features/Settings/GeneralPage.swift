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
