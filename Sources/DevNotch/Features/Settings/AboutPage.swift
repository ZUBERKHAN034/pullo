import AppKit
import SwiftUI

struct AboutPage: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Pullo").font(.title3.weight(.semibold))
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
