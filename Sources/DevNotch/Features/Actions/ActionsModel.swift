import Observation
import SwiftUI

@MainActor
@Observable
final class ActionsModel {
    private(set) var filter: RunFilter = .mine

    func select(_ filter: RunFilter) {
        withAnimation(Motion.navigate) { self.filter = filter }
    }
}
