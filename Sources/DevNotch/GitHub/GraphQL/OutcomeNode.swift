import Foundation

/// A PR looked up by ID after it left the open list.
struct OutcomeNode: Decodable {
    struct Person: Decodable {
        let login: String
        let avatarUrl: URL?
    }
    struct Timeline: Decodable {
        struct Closed: Decodable { let actor: Person? }
        let nodes: [Closed]
    }

    let id: String
    let state: String
    let mergedBy: Person?
    let timelineItems: Timeline

    var outcome: PROutcome {
        switch state {
        case "MERGED":
            return PROutcome(id: id, state: .merged, actor: mergedBy?.login, actorAvatar: mergedBy?.avatarUrl)
        case "CLOSED":
            let closer = timelineItems.nodes.last?.actor
            return PROutcome(id: id, state: .closed, actor: closer?.login, actorAvatar: closer?.avatarUrl)
        default:
            return PROutcome(id: id, state: .stillOpen, actor: nil, actorAvatar: nil)
        }
    }
}

struct OutcomeResponse: Decodable {
    struct Payload: Decodable { let nodes: [Lenient<OutcomeNode>] }
    let data: Payload?
}
