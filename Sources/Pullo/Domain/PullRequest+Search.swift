import Foundation

extension PullRequest {
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
