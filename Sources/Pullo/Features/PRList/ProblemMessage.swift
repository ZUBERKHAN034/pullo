import SwiftUI

struct ProblemMessage: View {
    @Environment(NotchInteraction.self) private var notch
    let problem: RefreshProblem
    let retry: () async -> Void

    var body: some View {
        MessageView(
            symbol: problem.symbol,
            title: problem.title,
            detail: problem.detail,
            actionTitle: problem.opensAccounts ? "Open Accounts" : "Try again"
        ) {
            if problem.opensAccounts {
                notch.onOpenSettings?(.accounts)
            } else {
                Task { await retry() }
            }
        }
    }
}
