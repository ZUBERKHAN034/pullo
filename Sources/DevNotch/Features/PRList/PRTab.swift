enum PRTab: Hashable {
    case mine, review
    case filter(SavedFilter.ID)

    var title: String {
        switch self {
        case .mine: String(localized: "My PRs")
        case .review: String(localized: "To review")
        case .filter: ""
        }
    }

    func rowKind(for pr: PullRequest) -> PRTab {
        guard case .filter = self else { return self }
        return pr.author.caseInsensitiveCompare(pr.account) == .orderedSame ? .mine : .review
    }
}
