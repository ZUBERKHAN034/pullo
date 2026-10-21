import Foundation

struct SavedFilter: AccountScoped, Codable, Hashable {
    enum Preset: String, Codable {
        case mine, review

        var query: String {
            switch self {
            case .mine: "author:@me"
            case .review: "review-requested:@me"
            }
        }

        var name: String {
            switch self {
            case .mine: String(localized: "My PRs")
            case .review: String(localized: "To review")
            }
        }
    }

    var id = UUID()
    var name: String
    var query: String
    var preset: Preset?
    var account: String?

    static func builtIn(_ preset: Preset) -> SavedFilter {
        SavedFilter(name: preset.name, query: preset.query, preset: preset)
    }

    static var defaults: [SavedFilter] { [.builtIn(.mine), .builtIn(.review)] }

    private var typedQuery: String {
        query.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    var usesBuiltInSearch: Bool {
        preset.map { typedQuery == $0.query } ?? false
    }

    var isComplete: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !typedQuery.isEmpty
    }

    var searchQuery: String {
        let typed = typedQuery
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
