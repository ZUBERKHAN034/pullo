import Foundation

struct GQLResponse: Decodable {
    struct Search: Decodable { let nodes: [Lenient<PRNode>] }

    struct Payload: Decodable {
        let mine: Search
        let review: Search
        let filtered: [String: Search]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: AliasKey.self)
            mine = try container.decode(Search.self, forKey: AliasKey("mine"))
            review = try container.decode(Search.self, forKey: AliasKey("review"))
            var filtered: [String: Search] = [:]
            for key in container.allKeys where key.stringValue != "mine" && key.stringValue != "review" {
                filtered[key.stringValue] = try? container.decodeIfPresent(Search.self, forKey: key)
            }
            self.filtered = filtered
        }
    }

    struct GQLError: Decodable {
        let message: String
        let path: [Lenient<String>]?

        var alias: String? { path?.first?.value }
    }

    let data: Payload?
    let errors: [GQLError]?
}

struct AliasKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
