import Foundation

enum PanelArea: CaseIterable {
    case pullRequests, actions

    var title: String {
        switch self {
        case .pullRequests: String(localized: "Pull requests")
        case .actions: String(localized: "Actions")
        }
    }

    var symbol: String {
        switch self {
        case .pullRequests: "arrow.triangle.pull"
        case .actions: "bolt.fill"
        }
    }
}
