

enum PRTab: CaseIterable {
    case mine, review

    var title: String {
        switch self {
        case .mine: String(localized: "My PRs")
        case .review: String(localized: "To review")
        }
    }
}
