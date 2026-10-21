import Foundation

enum RunFilter: CaseIterable {
    case mine, everyone, deploys

    var title: String {
        switch self {
        case .mine: String(localized: "Mine")
        case .everyone: String(localized: "Everyone")
        case .deploys: String(localized: "Deploys")
        }
    }

    func includes(_ run: WorkflowRun, login: String) -> Bool {
        switch self {
        case .mine: run.isStarted(by: login)
        case .everyone: true
        case .deploys: run.isDeploy
        }
    }
}
