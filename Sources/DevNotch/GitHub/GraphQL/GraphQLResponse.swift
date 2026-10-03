import Foundation

struct GQLResponse: Decodable {
    struct Payload: Decodable {
        struct Search: Decodable { let nodes: [Lenient<PRNode>] }
        let mine: Search
        let review: Search
    }
    struct GQLError: Decodable { let message: String }

    let data: Payload?
    let errors: [GQLError]?
}

/// Search results can carry nodes that are not pull requests; skip them instead of failing the whole response.
struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}
