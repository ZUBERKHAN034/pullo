import Foundation

extension PullRequest {
    /// Every word of the query has to appear in the title, repo, number, branch or author. A leading # is ignored.
    func matches(_ query: String) -> Bool {
        let terms = query.lowercased().split(separator: " ").map { $0.hasPrefix("#") ? $0.dropFirst() : $0 }
        guard !terms.isEmpty else { return false }
        let haystack = "\(title) \(repo) \(number) \(branch) \(author)".lowercased()
        return terms.allSatisfy { haystack.contains($0) }
    }
}
