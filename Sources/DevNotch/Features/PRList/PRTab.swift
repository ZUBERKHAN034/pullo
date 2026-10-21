enum PRTab: Hashable {
    case mine, review
    case filter(SavedFilter.ID)

    func rowKind(for pr: PullRequest) -> PRTab {
        guard case .filter = self else { return self }
        return pr.author.caseInsensitiveCompare(pr.account) == .orderedSame ? .mine : .review
    }
}
