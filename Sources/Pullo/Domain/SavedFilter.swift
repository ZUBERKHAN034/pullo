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

    enum Sort: String, Codable, CaseIterable {
        case updated, created

        var title: String {
            switch self {
            case .updated: String(localized: "Last updated")
            case .created: String(localized: "Newest first")
            }
        }

        func orders(_ a: PullRequest, before b: PullRequest) -> Bool {
            switch self {
            case .updated: a.updatedAt > b.updatedAt
            case .created: a.createdAt > b.createdAt
            }
        }
    }

    var id = UUID()
    var name: String
    var query: String
    var preset: Preset?
    var account: String?
    var sort: Sort?

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

extension SavedFilter {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        query = (try? container.decodeIfPresent(String.self, forKey: .query)) ?? ""
        preset = try? container.decodeIfPresent(Preset.self, forKey: .preset)
        account = try? container.decodeIfPresent(String.self, forKey: .account)
        sort = try? container.decodeIfPresent(Sort.self, forKey: .sort)
    }
}
