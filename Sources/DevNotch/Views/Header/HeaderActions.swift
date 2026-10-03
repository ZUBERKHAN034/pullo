import SwiftUI

struct HeaderActions: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var store: PRStore

    var body: some View {
        HStack(spacing: 2) {
            IconButton(symbol: "arrow.clockwise", help: "Refresh", spinning: store.isLoading) {
                Task { await store.refresh() }
            }
            IconButton(symbol: "magnifyingglass", help: "Search PRs (⌘F)", active: model.isSearching) {
                model.isSearching ? model.stopSearch() : model.startSearch()
            }
            IconButton(symbol: "person.2", help: "Accounts", active: model.screen == .accounts) { model.show(.accounts) }
            IconButton(symbol: "gearshape", help: "Settings") { model.onOpenSettings?() }
        }
    }
}
