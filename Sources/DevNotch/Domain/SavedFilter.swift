import Foundation

struct SavedFilter: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var query: String

    var isComplete: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var searchQuery: String {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = typed.lowercased()
        let pickedState = ["is:open", "is:closed", "is:merged", "is:unmerged", "state:"].contains { lowered.contains($0) }
        var parts = ["is:pr", "archived:false"]
        if !pickedState { parts.append("is:open") }
        parts.append(typed)
        if !lowered.contains("sort:") { parts.append("sort:updated-desc") }
        return parts.joined(separator: " ")
    }

    var webURL: URL? {
        var components = URLComponents(string: "https://github.com/pulls")
        components?.queryItems = [URLQueryItem(name: "q", value: searchQuery)]
        return components?.url
    }
}
