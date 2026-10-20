import SwiftUI

struct HeaderActions: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore

    var body: some View {
        HStack(spacing: 2) {
            IconButton(symbol: "arrow.triangle.2.circlepath", help: refreshHelp, spinning: store.isLoading) {
                Task { await store.refresh() }
            }
            IconButton(symbol: "gearshape", help: "Settings") { model.onOpenSettings?(nil) }
        }
    }

    private var refreshHelp: String {
        guard let updated = store.lastUpdated else { return "Refresh" }
        let age = updated.shortAge
        return age == "now" ? "Refresh · updated just now" : "Refresh · updated \(age) ago"
    }
}
