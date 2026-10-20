import SwiftUI

struct AppearancePage: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            if PanelStyle.glassIsAvailable {
                Section {
                    Picker("Style", selection: $settings.panelStyle) {
                        ForEach(PanelStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } footer: {
                    Text("Glass follows your Liquid Glass setting, and turns solid when Reduce transparency is on.")
                }
            }
            Section {
                Toggle("Show CI progress on the notch", isOn: $settings.showsLiveCI)
                    .toggleStyle(.switch)
            } footer: {
                Text("While checks run on your pull requests, the notch widens to show how many are done.")
            }
        }
    }
}
