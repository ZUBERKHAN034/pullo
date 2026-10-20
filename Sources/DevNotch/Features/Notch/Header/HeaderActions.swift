import SwiftUI

struct HeaderActions: View {
    @Environment(NotchInteraction.self) private var notch
    @Environment(PRStore.self) private var store

    var body: some View {
        HStack(spacing: 2) {
            IconButton(symbol: "arrow.triangle.2.circlepath", help: refreshHelp, spinning: store.isLoading) {
                Task { await store.refresh() }
            }
            IconButton(symbol: "gearshape", help: String(localized: "Settings")) { notch.onOpenSettings?(nil) }
        }
    }

    private var refreshHelp: String {
        guard let updated = store.lastUpdated else { return String(localized: "Refresh") }
        guard Date().timeIntervalSince(updated) >= 60 else { return String(localized: "Refresh · updated just now") }
        return String(localized: "Refresh · updated \(updated.shortAge) ago")
    }
}
