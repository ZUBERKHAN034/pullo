import Observation
import SwiftUI

@MainActor
@Observable
final class ActionsModel {
    static let recentLimit = 15

    private(set) var filter: RunFilter = .mine

    let store: RunStore
    private let list: PRListModel

    init(store: RunStore, list: PRListModel) {
        self.store = store
        self.list = list
    }

    var isLoaded: Bool { store.isLoaded(list.currentLogin) }

    var error: String? { list.currentLogin.flatMap { store.errors[$0] } }

    func runs(in filter: RunFilter) -> [WorkflowRun] {
        guard let login = list.currentLogin else { return [] }
        return store.runs(for: login).filter { filter.includes($0, login: login) }
    }

    var active: [WorkflowRun] { runs(in: filter).filter(\.state.isActive) }

    var recent: [WorkflowRun] {
        Array(runs(in: filter).filter { !$0.state.isActive }.sorted { $0.updatedAt > $1.updatedAt }.prefix(Self.recentLimit))
    }

    func activeCount(in filter: RunFilter) -> Int {
        runs(in: filter).filter(\.state.isActive).count
    }

    func select(_ filter: RunFilter) {
        withAnimation(Motion.navigate) { self.filter = filter }
    }
}
