import SwiftUI

struct HeaderActions: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore

    var body: some View {
        HStack(spacing: 2) {
            // Two arrows around a circle turn on their own center; the single clockwise arrow wobbles as it spins.
            IconButton(symbol: "arrow.triangle.2.circlepath", help: refreshHelp, spinning: store.isLoading) {
                Task { await store.refresh() }
            }
            IconButton(symbol: "gearshape", help: "Settings") { model.onOpenSettings?(nil) }
        }
    }

    /// When the list last updated lives here rather than taking room in the panel.
    private var refreshHelp: String {
        guard let updated = store.lastUpdated else { return "Refresh" }
        let age = updated.shortAge
        return age == "now" ? "Refresh · updated just now" : "Refresh · updated \(age) ago"
    }
}
