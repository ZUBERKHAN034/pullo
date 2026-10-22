import Foundation

struct PRQuery: Equatable {
    enum Author: String, CaseIterable {
        case me, anyone, user

        var title: String {
            switch self {
            case .me: String(localized: "Me")
            case .anyone: String(localized: "Anyone")
            case .user: String(localized: "Someone else")
            }
        }
    }

    enum Review: String, CaseIterable {
        case any, requestedFromMe, reviewedByMe, required, approved, changesRequested

        var title: String {
            switch self {
            case .any: String(localized: "Any")
            case .requestedFromMe: String(localized: "Requested from me")
            case .reviewedByMe: String(localized: "Reviewed by me")
            case .required: String(localized: "Waiting for review")
            case .approved: String(localized: "Approved")
            case .changesRequested: String(localized: "Changes requested")
            }
        }

        var token: String? {
            switch self {
            case .any: nil
            case .requestedFromMe: "review-requested:@me"
            case .reviewedByMe: "reviewed-by:@me"
            case .required: "review:required"
            case .approved: "review:approved"
            case .changesRequested: "review:changes_requested"
            }
        }
    }

    enum Checks: String, CaseIterable {
        case any, passing, failing, running

        var title: String {
            switch self {
            case .any: String(localized: "Any")
            case .passing: String(localized: "Passing")
            case .failing: String(localized: "Failing")
            case .running: String(localized: "Running")
            }
        }

        var token: String? {
            switch self {
            case .any: nil
            case .passing: "status:success"
            case .failing: "status:failure"
            case .running: "status:pending"
            }
        }
    }

    enum State: String, CaseIterable {
        case open, drafts, ready, merged, closed

        var title: String {
            switch self {
            case .open: String(localized: "Open")
            case .drafts: String(localized: "Drafts only")
            case .ready: String(localized: "Ready for review")
            case .merged: String(localized: "Merged")
            case .closed: String(localized: "Closed")
            }
        }

        var token: String? {
            switch self {
            case .open: nil
            case .drafts: "draft:true"
            case .ready: "draft:false"
            case .merged: "is:merged"
            case .closed: "is:closed"
            }
        }
    }

    var author: Author = .anyone
    var user = ""
    var review: Review = .any
    var repo = ""
    var label = ""
    var checks: Checks = .any
    var state: State = .open
    var extra = ""

    init() {}

    init(parsing query: String) {
        var taken = Set<String>()
        var rest: [String] = []
        for token in Self.tokens(in: query) {
            if !read(token, taken: &taken) { rest.append(token) }
        }
        extra = rest.joined(separator: " ")
    }

    var text: String {
        var parts: [String] = []
        switch author {
        case .me: parts.append("author:@me")
        case .anyone: break
        case .user:
            let login = user.trimmed.trimmingPrefix("@")
            if !login.isEmpty { parts.append("author:\(login)") }
        }
        if let token = review.token { parts.append(token) }
        if !repo.trimmed.isEmpty { parts.append("repo:\(repo.trimmed)") }
        if !label.trimmed.isEmpty { parts.append("label:\(Self.quoted(label.trimmed))") }
        if let token = checks.token { parts.append(token) }
        if let token = state.token { parts.append(token) }
        if !extra.trimmed.isEmpty { parts.append(extra.trimmed) }
        return parts.joined(separator: " ")
    }

    var isComplete: Bool {
        author != .user || !user.trimmed.trimmingPrefix("@").isEmpty
    }

    private mutating func read(_ token: String, taken: inout Set<String>) -> Bool {
        guard let colon = token.firstIndex(of: ":") else { return false }
        let key = token[..<colon].lowercased()
        let value = Self.unquoted(String(token[token.index(after: colon)...]))
        let lowered = value.lowercased()
        let field: String
        switch (key, lowered) {
        case ("author", _):
            guard !value.isEmpty else { return false }
            field = "author"
            guard !taken.contains(field) else { return false }
            if lowered == "@me" { author = .me } else { author = .user; user = value }
        case ("review-requested", "@me"), ("reviewed-by", "@me"), ("review", _):
            let match = Review.allCases.first { $0.token?.lowercased() == "\(key):\(lowered)" }
            guard let match else { return false }
            field = "review"
            guard !taken.contains(field) else { return false }
            review = match
        case ("repo", _), ("label", _):
            guard !value.isEmpty else { return false }
            field = key
            guard !taken.contains(field) else { return false }
            if key == "repo" { repo = value } else { label = value }
        case ("status", _):
            guard let match = Checks.allCases.first(where: { $0.token == "status:\(lowered)" }) else { return false }
            field = "checks"
            guard !taken.contains(field) else { return false }
            checks = match
        case ("is", "open"), ("is", "draft"), ("draft", "true"), ("draft", "false"), ("is", "merged"), ("is", "closed"):
            field = "state"
            guard !taken.contains(field) else { return false }
            state = switch (key, lowered) {
            case ("is", "draft"), ("draft", "true"): .drafts
            case ("draft", "false"): .ready
            case ("is", "merged"): .merged
            case ("is", "closed"): .closed
            default: .open
            }
        default:
            return false
        }
        taken.insert(field)
        return true
    }

    static func tokens(in query: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        for character in query {
            if character == "\"" { inQuotes.toggle() }
            if character.isWhitespace, !inQuotes {
                if !current.isEmpty { tokens.append(current) }
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func quoted(_ value: String) -> String {
        value.contains(where: \.isWhitespace) ? "\"\(value)\"" : value
    }

    private static func unquoted(_ value: String) -> String {
        value.count >= 2 && value.hasPrefix("\"") && value.hasSuffix("\"") ? String(value.dropFirst().dropLast()) : value
    }
}
