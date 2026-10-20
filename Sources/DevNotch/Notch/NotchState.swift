/// How much of the notch is showing.
enum NotchState: Equatable {
    case closed, peek, open
}

enum PRTab: CaseIterable {
    case mine, review

    var title: String {
        switch self {
        case .mine: "My PRs"
        case .review: "To review"
        }
    }
}
