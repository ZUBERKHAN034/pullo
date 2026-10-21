import Foundation

struct OutcomeResponse: Decodable {
    struct Payload: Decodable { let nodes: [Lenient<OutcomeNode>] }
    let data: Payload?
}
