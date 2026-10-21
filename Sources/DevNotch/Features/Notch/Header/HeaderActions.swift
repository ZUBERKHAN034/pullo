import SwiftUI

struct HeaderActions: View {
    @Environment(NotchInteraction.self) private var notch
    @Environment(PRStore.self) private var store
    @Environment(\.panelGlass) private var glass

    var body: some View {
        HStack(spacing: glass ? 6 : 2) {
            IconButton(symbol: "arrow.triangle.2.circlepath", help: refreshHelp, spinning: store.isLoading, floating: true) {
                Task { await store.refresh() }
            }
            IconButton(symbol: "gearshape", help: String(localized: "Settings"), floating: true) { notch.onOpenSettings?(nil) }
        }
        .glassGroup(spacing: 6)
    }

    private var refreshHelp: String {
        guard let updated = store.lastUpdated else { return String(localized: "Refresh") }
        guard Date().timeIntervalSince(updated) >= 60 else { return String(localized: "Refresh · updated just now") }
        return String(localized: "Refresh · updated \(updated.shortAge) ago")
    }
}
