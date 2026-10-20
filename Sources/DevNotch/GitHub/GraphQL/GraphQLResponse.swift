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
