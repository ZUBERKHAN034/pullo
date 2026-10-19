import SwiftUI

struct HeaderActions: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore

    var body: some View {
        HStack(spacing: 2) {
            IconButton(symbol: "arrow.clockwise", help: refreshHelp, spinning: store.isLoading) {
                Task { await store.refresh() }
            }
            IconButton(symbol: "person.2", help: "Accounts", active: model.screen == .accounts) { model.show(.accounts) }
            IconButton(symbol: "gearshape", help: "Settings") { model.onOpenSettings?() }
        }
    }

    /// When the list last updated lives here rather than taking room in the panel.
    private var refreshHelp: String {
        guard let updated = store.lastUpdated else { return "Refresh" }
        let age = updated.shortAge
        return age == "now" ? "Refresh · updated just now" : "Refresh · updated \(age) ago"
    }
}
