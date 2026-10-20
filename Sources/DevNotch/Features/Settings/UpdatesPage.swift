import AppKit
import SwiftUI

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
