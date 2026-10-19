import Foundation

extension PullRequest {
    /// Every word of the query has to appear in the title, repo, branch or author, or be the PR's number.
    /// `#12` only finds PR 12; a bare `12` also finds it in titles and branches.
    func matches(_ query: String) -> Bool {
        let terms = query.lowercased().split(separator: " ")
        guard !terms.isEmpty else { return false }
        let haystack = "\(title) \(repo) \(branch) \(author)".lowercased()
        return terms.allSatisfy { term in
            if term.hasPrefix("#") { return term.dropFirst() == "\(number)" }
            return term == "\(number)" || haystack.contains(term)
        }
    }
}
